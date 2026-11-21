use serde::{Deserialize, Serialize};

pub const DEFAULT_SIZE: u32 = 1568;
pub const DEFAULT_FONT: &str = "8x13";
pub const DEFAULT_FALLBACK_FONT: &str = "silver";
pub const DEFAULT_VARIANT: &str = "bw";
pub const DEFAULT_COLUMNS: u32 = 1;
pub const DEFAULT_MAX_FRAMES: usize = 40;

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct RenderRequest {
    pub text: String,
    pub font: String,
    pub fallback_font: String,
    pub size: u32,
    pub variant: String,
    pub columns: u32,
    pub max_frames: usize,
}

impl Default for RenderRequest {
    fn default() -> Self {
        Self {
            text: String::new(),
            font: DEFAULT_FONT.to_string(),
            fallback_font: DEFAULT_FALLBACK_FONT.to_string(),
            size: DEFAULT_SIZE,
            variant: DEFAULT_VARIANT.to_string(),
            columns: DEFAULT_COLUMNS,
            max_frames: DEFAULT_MAX_FRAMES,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameEntry {
    pub file: String,
    pub width: u32,
    pub height: u32,
    pub chars: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub frames: Vec<FrameEntry>,
    pub truncated: bool,
    pub font: String,
}
