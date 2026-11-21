use std::{collections::HashMap, sync::LazyLock};

use fontdue::{Font as TtfFace, FontSettings};

pub const DIM_ON: u32 = 0x0e;
pub const DIM_OFF: u32 = 0x0f;
pub const FULL_BLOCK: u32 = 0x2588;
pub const SILVER_PX: f32 = 16.0;
pub const SILVER_CELL: usize = 16;

static FONT_5X8: LazyLock<BitmapFont> =
    LazyLock::new(|| parse_bdf(include_str!("../fonts/5x8.bdf"), 5, 8));
static FONT_8X8: LazyLock<BitmapFont> =
    LazyLock::new(|| parse_hex(include_str!("../fonts/unscii-8.hex")));
static FONT_6X12: LazyLock<BitmapFont> =
    LazyLock::new(|| parse_bdf(include_str!("../fonts/6x12.bdf"), 6, 12));
static FONT_8X13: LazyLock<BitmapFont> =
    LazyLock::new(|| parse_bdf(include_str!("../fonts/8x13.bdf"), 8, 13));
static FONT_SILVER: LazyLock<TtfFont> = LazyLock::new(|| {
    let face = TtfFace::from_bytes(
        include_bytes!("../fonts/Silver.ttf").as_slice(),
        FontSettings::default(),
    )
    .expect("bundled Silver.ttf must parse");
    let ascent = face
        .horizontal_line_metrics(SILVER_PX)
        .map_or(SILVER_PX * 0.8, |metrics| metrics.ascent);
    TtfFont { face, ascent }
});

pub struct Glyph {
    pub w: u8,
    pub h: i32,
    pub xoff: i32,
    pub yoff: i32,
    pub rows: Vec<u8>,
}

pub struct BitmapFont {
    pub glyphs: HashMap<u32, Glyph>,
    pub ascent: i32,
    pub cell_w: usize,
    pub cell_h: usize,
}

pub struct TtfFont {
    pub face: TtfFace,
    pub ascent: f32,
}

impl BitmapFont {
    pub fn fallback(&self) -> &'static TtfFont {
        &FONT_SILVER
    }
}

pub enum RenderFont<'a> {
    Bitmap(&'a BitmapFont),
    Ttf(&'a TtfFont),
}

impl RenderFont<'_> {
    pub fn cell_w(&self) -> usize {
        match self {
            Self::Bitmap(font) => font.cell_w,
            Self::Ttf(_) => SILVER_CELL,
        }
    }

    pub fn cell_h(&self) -> usize {
        match self {
            Self::Bitmap(font) => font.cell_h,
            Self::Ttf(_) => SILVER_CELL,
        }
    }

    pub fn is_bitmap(&self) -> bool {
        matches!(self, Self::Bitmap(_))
    }

    pub fn supports(&self, code: u32) -> bool {
        if matches!(code, DIM_ON | DIM_OFF | FULL_BLOCK | 0x0a) {
            return true;
        }
        match self {
            Self::Bitmap(font) => font.glyphs.contains_key(&code),
            Self::Ttf(font) => {
                char::from_u32(code).is_some_and(|ch| font.face.lookup_glyph_index(ch) != 0)
            }
        }
    }

    pub fn supports_text(&self, text: &str) -> bool {
        text.chars().all(|ch| self.supports(ch as u32))
    }
}

pub fn resolve_font(name: &str) -> Option<RenderFont<'static>> {
    match name {
        "5x8" => Some(RenderFont::Bitmap(&FONT_5X8)),
        "8x8" => Some(RenderFont::Bitmap(&FONT_8X8)),
        "6x12" => Some(RenderFont::Bitmap(&FONT_6X12)),
        "8x13" => Some(RenderFont::Bitmap(&FONT_8X13)),
        "silver" => Some(RenderFont::Ttf(&FONT_SILVER)),
        _ => None,
    }
}

pub fn font_names() -> &'static str {
    "\"5x8\", \"8x8\", \"6x12\", \"8x13\", or \"silver\""
}

fn parse_bdf(text: &str, cell_w: usize, cell_h: usize) -> BitmapFont {
    let mut glyphs = HashMap::new();
    let mut ascent = 0i32;
    let mut enc = -1i64;
    let mut bbx = [0i32; 4];
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if let Some(rest) = line.strip_prefix("FONT_ASCENT") {
            ascent = rest.trim().parse().unwrap_or(0);
        } else if let Some(rest) = line.strip_prefix("ENCODING") {
            enc = rest.trim().parse().unwrap_or(-1);
        } else if let Some(rest) = line.strip_prefix("BBX") {
            let mut parts = rest.split_ascii_whitespace();
            for slot in &mut bbx {
                *slot = parts.next().and_then(|part| part.parse().ok()).unwrap_or(0);
            }
        } else if line.starts_with("BITMAP") {
            let mut rows = Vec::new();
            for row in lines.by_ref() {
                if row.starts_with("ENDCHAR") {
                    break;
                }
                rows.push(u8::from_str_radix(row.trim(), 16).unwrap_or(0));
            }
            if enc >= 0 {
                glyphs.insert(
                    enc as u32,
                    Glyph {
                        w: bbx[0].clamp(0, 8) as u8,
                        h: bbx[1],
                        xoff: bbx[2],
                        yoff: bbx[3],
                        rows,
                    },
                );
            }
        }
    }
    BitmapFont {
        glyphs,
        ascent,
        cell_w,
        cell_h,
    }
}

fn parse_hex(text: &str) -> BitmapFont {
    let mut glyphs = HashMap::new();
    for line in text.lines() {
        let Some((cp, bits)) = line.split_once(':') else {
            continue;
        };
        let Ok(enc) = u32::from_str_radix(cp.trim(), 16) else {
            continue;
        };
        let bits = bits.trim();
        if bits.len() != 16 {
            continue;
        }
        let rows: Vec<u8> = (0..8)
            .map(|i| u8::from_str_radix(&bits[i * 2..i * 2 + 2], 16).unwrap_or(0))
            .collect();
        glyphs.insert(
            enc,
            Glyph {
                w: 8,
                h: 8,
                xoff: 0,
                yoff: -1,
                rows,
            },
        );
    }
    BitmapFont {
        glyphs,
        ascent: 7,
        cell_w: 8,
        cell_h: 8,
    }
}
