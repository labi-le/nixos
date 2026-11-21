use anyhow::{bail, Context, Result};

use crate::fonts::{font_names, resolve_font, RenderFont};
use crate::protocol::{FrameEntry, Manifest, RenderRequest};
use crate::render::{doc_column_width, render_frame, Grid, MAX_FRAME_SIZE};
use crate::wrap::{paginate, wrap, Line};

pub struct Frame {
    pub file: String,
    pub png: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub chars: usize,
}

pub struct FrameSet {
    pub frames: Vec<Frame>,
    pub truncated: bool,
    pub font: String,
}

impl FrameSet {
    pub fn manifest(&self) -> Manifest {
        Manifest {
            frames: self
                .frames
                .iter()
                .map(|frame| FrameEntry {
                    file: frame.file.clone(),
                    width: frame.width,
                    height: frame.height,
                    chars: frame.chars,
                })
                .collect(),
            truncated: self.truncated,
            font: self.font.clone(),
        }
    }
}

pub struct Shape {
    pub columns: u32,
    pub black_ink: bool,
    pub size: u32,
    pub max_frames: usize,
}

impl Shape {
    pub fn from_request(req: &RenderRequest) -> Result<Self> {
        if req.size == 0 || req.size > MAX_FRAME_SIZE {
            bail!(
                "invalid frame size {}: expected 1..={MAX_FRAME_SIZE}",
                req.size
            );
        }
        if !matches!(req.columns, 1 | 2) {
            bail!("invalid columns {}: expected 1 or 2", req.columns);
        }
        if req.max_frames == 0 {
            bail!("invalid max_frames 0: expected at least 1");
        }
        let black_ink = match req.variant.as_str() {
            "sent" => false,
            "bw" => true,
            other => bail!("unknown variant {other:?}: expected \"sent\" or \"bw\""),
        };
        Ok(Self {
            columns: req.columns,
            black_ink,
            size: req.size,
            max_frames: req.max_frames,
        })
    }
}

pub fn select_font(req: &RenderRequest) -> Result<(String, RenderFont<'static>)> {
    if let Some(font) = resolve_font(&req.font) {
        return Ok((req.font.clone(), font));
    }
    let fallback = resolve_font(&req.fallback_font).with_context(|| {
        format!(
            "unknown font {:?} and unknown fallback {:?}: expected {}",
            req.font,
            req.fallback_font,
            font_names()
        )
    })?;
    Ok((req.fallback_font.clone(), fallback))
}

pub fn build(req: &RenderRequest) -> Result<FrameSet> {
    let shape = Shape::from_request(req)?;
    let (font_name, font) = select_font(req)?;
    let canvas_w = shape.size as usize;
    let grid = Grid {
        cols: canvas_w / font.cell_w(),
        rows: canvas_w / font.cell_h(),
        cell_w: font.cell_w(),
        cell_h: font.cell_h(),
    };
    if grid.cols == 0 || grid.rows == 0 {
        bail!(
            "frame size {} cannot fit a {}x{} cell grid",
            canvas_w,
            grid.cell_w,
            grid.cell_h
        );
    }
    let doc = shape.columns == 2;
    let line_width = if doc {
        doc_column_width(grid.cols)
    } else {
        grid.cols
    };
    let per_page = if doc { grid.rows * 2 } else { grid.rows };
    let lines = wrap(&req.text, line_width, font.is_bitmap());
    let (ranges, truncated) = paginate(lines.len(), per_page, shape.max_frames);

    let mut frames = Vec::with_capacity(ranges.len());
    for (index, range) in ranges.iter().enumerate() {
        let page = &lines[range.clone()];
        let chars = page.iter().map(|line| line.text.chars().count()).sum();
        let text = page_text(page, line_width, doc);
        let rendered = render_frame(&text, canvas_w, &font, &grid, doc, shape.black_ink)?;
        frames.push(Frame {
            file: format!("frame-{index:03}.png"),
            png: rendered.png,
            width: rendered.width,
            height: rendered.height,
            chars,
        });
    }
    Ok(FrameSet {
        frames,
        truncated,
        font: font_name,
    })
}

fn page_text(lines: &[Line], line_width: usize, doc: bool) -> String {
    if doc {
        let texts: Vec<&str> = lines.iter().map(|line| line.text.as_str()).collect();
        return texts.join("\n");
    }
    let mut text = String::new();
    for line in lines {
        text.push_str(&line.text);
        if line.width < line_width {
            text.extend(std::iter::repeat_n(' ', line_width - line.width));
        }
    }
    text
}
