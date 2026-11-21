use std::{borrow::Cow, collections::HashMap, iter::Peekable, str::Chars};

use anyhow::{bail, Result};
use fontdue::Metrics;

use crate::fonts::{
    BitmapFont, Glyph, RenderFont, TtfFont, DIM_OFF, DIM_ON, FULL_BLOCK, SILVER_CELL, SILVER_PX,
};

pub const MAX_FRAME_SIZE: u32 = 16384;
pub const MIN_FRAME_HEIGHT: usize = 64;
pub const GUTTER: usize = 3;

const PALETTE: [[u8; 3]; 10] = [
    [255, 255, 255],
    [109, 2, 2],
    [109, 53, 2],
    [24, 109, 2],
    [2, 109, 109],
    [2, 32, 109],
    [75, 2, 109],
    [0, 0, 0],
    [255, 247, 194],
    [128, 128, 128],
];
const INK_COLORS: usize = 6;
const INK_BLACK: u8 = 7;
const INK_DIM: u8 = 9;

pub struct Grid {
    pub cols: usize,
    pub rows: usize,
    pub cell_w: usize,
    pub cell_h: usize,
}

pub struct RenderedFrame {
    pub png: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

pub const fn is_wide(cp: u32) -> bool {
    matches!(cp,
        0x1100..=0x115F
        | 0x2E80..=0x2EFF
        | 0x2F00..=0x2FDF
        | 0x3000..=0x303E
        | 0x3041..=0x33FF
        | 0x3400..=0x4DBF
        | 0x4E00..=0x9FFF
        | 0xA000..=0xA4CF
        | 0xAC00..=0xD7A3
        | 0xF900..=0xFAFF
        | 0xFE30..=0xFE4F
        | 0xFF00..=0xFF60
        | 0xFFE0..=0xFFE6
        | 0x20000..=0x2FFFD
        | 0x30000..=0x3FFFD
    )
}

pub fn doc_column_width(cols: usize) -> usize {
    cols.saturating_sub(GUTTER) / 2
}

struct LaidCell {
    ch: char,
    ink: u8,
    x: usize,
    row: usize,
    units: usize,
}

struct Layout<'a> {
    chars: Peekable<Chars<'a>>,
    grid: &'a Grid,
    doc: bool,
    col_w: usize,
    wide_cells: bool,
    black_ink: bool,
    sentence: usize,
    dim: bool,
    cursor: usize,
    line: usize,
}

impl<'a> Layout<'a> {
    fn new(text: &'a str, grid: &'a Grid, doc: bool, wide_cells: bool, black_ink: bool) -> Self {
        Self {
            chars: text.chars().peekable(),
            grid,
            doc,
            col_w: doc_column_width(grid.cols),
            wide_cells,
            black_ink,
            sentence: 0,
            dim: false,
            cursor: 0,
            line: 0,
        }
    }

    fn is_empty(&self) -> bool {
        if self.doc {
            self.col_w == 0 || self.grid.rows == 0
        } else {
            self.grid.cols * self.grid.rows == 0
        }
    }

    fn used_rows(mut self) -> usize {
        self.by_ref().for_each(drop);
        let rows = if self.doc {
            self.line + 1
        } else {
            self.cursor.div_ceil(self.grid.cols)
        };
        rows.clamp(1, self.grid.rows)
    }
}

impl Iterator for Layout<'_> {
    type Item = LaidCell;

    fn next(&mut self) -> Option<LaidCell> {
        let grid = self.grid;
        loop {
            if !self.doc && self.cursor >= grid.cols * grid.rows {
                return None;
            }
            let ch = self.chars.next()?;
            let code = ch as u32;
            match code {
                DIM_ON => {
                    self.dim = true;
                    continue;
                }
                DIM_OFF => {
                    self.dim = false;
                    continue;
                }
                0x0a if self.doc => {
                    self.line += 1;
                    self.cursor = 0;
                    if self.line >= grid.rows * 2 {
                        return None;
                    }
                    continue;
                }
                _ => {}
            }
            let ink = if self.dim {
                INK_DIM
            } else if self.black_ink {
                INK_BLACK
            } else {
                (1 + self.sentence % INK_COLORS) as u8
            };
            if matches!(code, 0x2e | 0x21 | 0x3f)
                && self.chars.peek().is_some_and(|&next| {
                    matches!(next as u32, 0x20 | FULL_BLOCK) || (self.doc && next == '\n')
                })
            {
                self.sentence += 1;
            }
            let units = if self.wide_cells && is_wide(code) {
                2
            } else {
                1
            };
            let mut cell = self.cursor;
            if self.doc {
                if units == 2 && self.col_w >= 2 && cell == self.col_w - 1 {
                    cell += 1;
                }
                self.cursor = cell + units;
                if self.cursor > self.col_w {
                    continue;
                }
                let column = self.line / grid.rows;
                let row = self.line - column * grid.rows;
                let x = (column * (self.col_w + GUTTER) + cell) * grid.cell_w;
                return Some(LaidCell {
                    ch,
                    ink,
                    x,
                    row,
                    units,
                });
            }
            if units == 2 && grid.cols >= 2 && cell % grid.cols == grid.cols - 1 {
                cell += 1;
            }
            self.cursor = cell + units;
            if cell >= grid.cols * grid.rows {
                return None;
            }
            let row = cell / grid.cols;
            let x = (cell - row * grid.cols) * grid.cell_w;
            return Some(LaidCell {
                ch,
                ink,
                x,
                row,
                units,
            });
        }
    }
}

fn blit_glyph(
    pixels: &mut [u8],
    width: usize,
    height: usize,
    glyph: &Glyph,
    left: i32,
    top: i32,
    ink: u8,
) {
    for (r, &bits) in glyph.rows.iter().enumerate() {
        if bits == 0 {
            continue;
        }
        let y = top + r as i32;
        if y < 0 || y >= height as i32 {
            continue;
        }
        let row_base = y as usize * width;
        for b in 0..glyph.w {
            if bits & (0x80u8 >> b) != 0 {
                let x = left + i32::from(b);
                if x >= 0 && (x as usize) < width {
                    pixels[row_base + x as usize] = ink;
                }
            }
        }
    }
}

fn fill_cell(
    pixels: &mut [u8],
    width: usize,
    height: usize,
    grid: &Grid,
    x_origin: usize,
    row: usize,
    ink: u8,
) {
    let x0 = x_origin.min(width);
    let x1 = (x_origin + grid.cell_w).min(width);
    if x0 >= x1 {
        return;
    }
    let top = row * grid.cell_h;
    for y in top..(top + grid.cell_h).min(height) {
        pixels[y * width + x0..y * width + x1].fill(ink);
    }
}

fn fill_cell_rgb(
    pixels: &mut [u8],
    width: usize,
    height: usize,
    grid: &Grid,
    x_origin: usize,
    row: usize,
    ink: u8,
) {
    let x0 = x_origin.min(width);
    let x1 = (x_origin + grid.cell_w).min(width);
    if x0 >= x1 {
        return;
    }
    let color = PALETTE[ink as usize];
    let top = row * grid.cell_h;
    for y in top..(top + grid.cell_h).min(height) {
        let line = &mut pixels[y * width * 3..(y + 1) * width * 3];
        for x in x0..x1 {
            line[x * 3..x * 3 + 3].copy_from_slice(&color);
        }
    }
}

fn ttf_pixel_size(grid: &Grid, units: usize) -> f32 {
    let sx = (units * grid.cell_w) as f32 / SILVER_CELL as f32;
    let sy = grid.cell_h as f32 / SILVER_CELL as f32;
    SILVER_PX * sx.min(sy)
}

fn ttf_ascent(font: &TtfFont, px: f32) -> f32 {
    font.face
        .horizontal_line_metrics(px)
        .map_or(font.ascent * px / SILVER_PX, |metrics| metrics.ascent)
}

fn cached_ttf_glyph<'a>(
    cache: &'a mut HashMap<char, RasterizedGlyph>,
    font: &TtfFont,
    ch: char,
    px: f32,
) -> Option<&'a RasterizedGlyph> {
    if font.face.lookup_glyph_index(ch) == 0 {
        return None;
    }
    Some(cache.entry(ch).or_insert_with(|| {
        let (metrics, bitmap) = font.face.rasterize(ch, px);
        RasterizedGlyph { metrics, bitmap }
    }))
}

struct RasterizedGlyph {
    metrics: Metrics,
    bitmap: Vec<u8>,
}

fn blit_ttf_glyph(
    pixels: &mut [u8],
    width: usize,
    height: usize,
    glyph: &RasterizedGlyph,
    left: i32,
    top: i32,
    ink: u8,
) {
    if glyph.metrics.width == 0 || glyph.metrics.height == 0 {
        return;
    }
    let color = PALETTE[ink as usize];
    for y in 0..glyph.metrics.height {
        let dst_y = top + y as i32;
        if dst_y < 0 || dst_y >= height as i32 {
            continue;
        }
        for x in 0..glyph.metrics.width {
            let alpha = u16::from(glyph.bitmap[y * glyph.metrics.width + x]);
            if alpha == 0 {
                continue;
            }
            let dst_x = left + x as i32;
            if dst_x < 0 || dst_x >= width as i32 {
                continue;
            }
            let offset = (dst_y as usize * width + dst_x as usize) * 3;
            let inv = 255 - alpha;
            for c in 0..3 {
                let bg = u16::from(pixels[offset + c]);
                let fg = u16::from(color[c]);
                pixels[offset + c] = ((bg * inv + fg * alpha + 127) / 255) as u8;
            }
        }
    }
}

fn blit_ttf_glyph_indexed(
    pixels: &mut [u8],
    width: usize,
    height: usize,
    glyph: &RasterizedGlyph,
    left: i32,
    top: i32,
    ink: u8,
) {
    if glyph.metrics.width == 0 || glyph.metrics.height == 0 {
        return;
    }
    for y in 0..glyph.metrics.height {
        let dst_y = top + y as i32;
        if dst_y < 0 || dst_y >= height as i32 {
            continue;
        }
        let row_base = dst_y as usize * width;
        for x in 0..glyph.metrics.width {
            let coverage = glyph.bitmap[y * glyph.metrics.width + x];
            let cell = if coverage >= 170 {
                ink
            } else if ink == INK_BLACK && coverage >= 56 {
                INK_DIM
            } else if coverage >= 110 {
                ink
            } else {
                continue;
            };
            let dst_x = left + x as i32;
            if dst_x >= 0 && dst_x < width as i32 {
                pixels[row_base + dst_x as usize] = cell;
            }
        }
    }
}

fn ttf_glyph_origin(x_origin: usize, cell_w: usize, metrics: &Metrics) -> i32 {
    let advance = metrics.advance_width.ceil() as i32;
    let pad = (cell_w as i32 - advance).max(0) / 2;
    x_origin as i32 + pad + metrics.xmin
}

fn ttf_glyph_top(cell_top: usize, ascent: f32, metrics: &Metrics) -> i32 {
    (cell_top as f32 + ascent - metrics.height as f32 - metrics.ymin as f32).round() as i32
}

fn render_bitmap(
    text: &str,
    width: usize,
    height: usize,
    font: &BitmapFont,
    grid: &Grid,
    doc: bool,
    black_ink: bool,
) -> Vec<u8> {
    let mut pixels = vec![0u8; width * height];
    let layout = Layout::new(text, grid, doc, true, black_ink);
    if layout.is_empty() {
        return pixels;
    }
    let mut fallback_cache = HashMap::new();
    for cell in layout {
        if cell.ch as u32 == FULL_BLOCK {
            fill_cell(
                &mut pixels,
                width,
                height,
                grid,
                cell.x,
                cell.row,
                INK_BLACK,
            );
            continue;
        }
        if let Some(glyph) = font.glyphs.get(&(cell.ch as u32)) {
            if glyph.rows.is_empty() {
                continue;
            }
            let left = cell.x as i32 + glyph.xoff;
            let cell_top = (cell.row * grid.cell_h) as i32;
            let top = cell_top + font.ascent - glyph.h - glyph.yoff;
            blit_glyph(&mut pixels, width, height, glyph, left, top, cell.ink);
        } else {
            let px = ttf_pixel_size(grid, cell.units);
            let Some(glyph) = cached_ttf_glyph(&mut fallback_cache, font.fallback(), cell.ch, px)
            else {
                continue;
            };
            let left = ttf_glyph_origin(cell.x, cell.units * grid.cell_w, &glyph.metrics);
            let cell_top = cell.row * grid.cell_h;
            let top = ttf_glyph_top(cell_top, font.ascent as f32, &glyph.metrics);
            blit_ttf_glyph_indexed(&mut pixels, width, height, glyph, left, top, cell.ink);
        }
    }
    pixels
}

fn render_ttf_rgb(
    text: &str,
    width: usize,
    height: usize,
    font: &TtfFont,
    grid: &Grid,
    doc: bool,
    black_ink: bool,
) -> Vec<u8> {
    let mut pixels = vec![255u8; width * height * 3];
    let layout = Layout::new(text, grid, doc, false, black_ink);
    if layout.is_empty() {
        return pixels;
    }
    let px = ttf_pixel_size(grid, 1);
    let ascent = ttf_ascent(font, px);
    let mut cache = HashMap::new();
    for cell in layout {
        if cell.ch as u32 == FULL_BLOCK {
            fill_cell_rgb(
                &mut pixels,
                width,
                height,
                grid,
                cell.x,
                cell.row,
                INK_BLACK,
            );
            continue;
        }
        let Some(glyph) = cached_ttf_glyph(&mut cache, font, cell.ch, px) else {
            continue;
        };
        let left = ttf_glyph_origin(cell.x, grid.cell_w, &glyph.metrics);
        let cell_top = cell.row * grid.cell_h;
        let top = ttf_glyph_top(cell_top, ascent, &glyph.metrics);
        blit_ttf_glyph(&mut pixels, width, height, glyph, left, top, cell.ink);
    }
    pixels
}

fn pack_bits(
    pixels: &[u8],
    width: usize,
    height: usize,
    bits: usize,
    remap: &[u8; PALETTE.len()],
) -> Vec<u8> {
    let per = 8 / bits;
    let row_bytes = width.div_ceil(per);
    let mut packed = vec![0u8; row_bytes * height];
    for y in 0..height {
        let src = &pixels[y * width..(y + 1) * width];
        let dst = &mut packed[y * row_bytes..(y + 1) * row_bytes];
        for (x, &px) in src.iter().enumerate() {
            dst[x / per] |= remap[px as usize] << (bits * (per - 1 - x % per));
        }
    }
    packed
}

fn encode_indexed_png(
    pixels: &[u8],
    width: usize,
    height: usize,
    compression: png::Compression,
) -> Result<Vec<u8>> {
    let mut used = [false; PALETTE.len()];
    for &px in pixels {
        used[px as usize] = true;
    }
    let mut remap = [0u8; PALETTE.len()];
    let mut palette = Vec::with_capacity(PALETTE.len() * 3);
    let mut count = 0u8;
    for (global, &is_used) in used.iter().enumerate() {
        if is_used {
            remap[global] = count;
            count += 1;
            palette.extend_from_slice(&PALETTE[global]);
        }
    }
    let (depth, bits) = match count {
        0..=2 => (png::BitDepth::One, 1),
        3..=4 => (png::BitDepth::Two, 2),
        _ => (png::BitDepth::Four, 4),
    };
    let mut out = Vec::new();
    let mut encoder = png::Encoder::new(&mut out, width as u32, height as u32);
    encoder.set_color(png::ColorType::Indexed);
    encoder.set_depth(depth);
    encoder.set_palette(Cow::Owned(palette));
    encoder.set_compression(compression);
    encoder.set_filter(png::Filter::NoFilter);
    let mut writer = encoder
        .write_header()
        .map_err(|err| anyhow::anyhow!("failed to write PNG header: {err}"))?;
    writer
        .write_image_data(&pack_bits(pixels, width, height, bits, &remap))
        .map_err(|err| anyhow::anyhow!("failed to write PNG data: {err}"))?;
    writer
        .finish()
        .map_err(|err| anyhow::anyhow!("failed to finish PNG stream: {err}"))?;
    Ok(out)
}

fn encode_rgb_png(
    pixels: &[u8],
    width: usize,
    height: usize,
    compression: png::Compression,
) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    let mut encoder = png::Encoder::new(&mut out, width as u32, height as u32);
    encoder.set_color(png::ColorType::Rgb);
    encoder.set_depth(png::BitDepth::Eight);
    encoder.set_compression(compression);
    let mut writer = encoder
        .write_header()
        .map_err(|err| anyhow::anyhow!("failed to write PNG header: {err}"))?;
    writer
        .write_image_data(pixels)
        .map_err(|err| anyhow::anyhow!("failed to write PNG data: {err}"))?;
    writer
        .finish()
        .map_err(|err| anyhow::anyhow!("failed to finish PNG stream: {err}"))?;
    Ok(out)
}

pub fn render_frame(
    text: &str,
    canvas_w: usize,
    font: &RenderFont<'_>,
    grid: &Grid,
    doc: bool,
    black_ink: bool,
) -> Result<RenderedFrame> {
    if canvas_w == 0 || canvas_w > MAX_FRAME_SIZE as usize {
        bail!("invalid frame size {canvas_w}: expected 1..={MAX_FRAME_SIZE}");
    }
    if grid.cols == 0 || grid.rows == 0 {
        bail!(
            "frame size {canvas_w} cannot fit a {}x{} cell grid",
            grid.cell_w,
            grid.cell_h
        );
    }
    let used = Layout::new(text, grid, doc, font.is_bitmap(), black_ink).used_rows();
    let content_height = used * grid.cell_h;
    let height = content_height.max(MIN_FRAME_HEIGHT);
    let png = match font {
        RenderFont::Ttf(face) => {
            let mut pixels = render_ttf_rgb(text, canvas_w, height, face, grid, doc, black_ink);
            pixels[content_height * canvas_w * 3..].fill(255);
            encode_rgb_png(&pixels, canvas_w, height, png::Compression::High)?
        }
        RenderFont::Bitmap(bitmap) => {
            let mut pixels = render_bitmap(text, canvas_w, height, bitmap, grid, doc, black_ink);
            pixels[content_height * canvas_w..].fill(0);
            encode_indexed_png(&pixels, canvas_w, height, png::Compression::High)?
        }
    };
    Ok(RenderedFrame {
        png,
        width: canvas_w as u32,
        height: height as u32,
    })
}
