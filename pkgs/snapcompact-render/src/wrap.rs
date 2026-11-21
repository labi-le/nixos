use std::ops::Range;

use crate::fonts::{DIM_OFF, DIM_ON};
use crate::render::is_wide;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Kind {
    Word,
    Space,
    Break,
}

#[derive(Default, Clone)]
struct Unit {
    text: String,
    width: usize,
}

struct Token {
    kind: Kind,
    units: Vec<Unit>,
    width: usize,
}

#[derive(Default, Clone, Debug, PartialEq, Eq)]
pub struct Line {
    pub text: String,
    pub width: usize,
}

pub fn char_cells(ch: char, wide_cells: bool) -> usize {
    if wide_cells && is_wide(ch as u32) {
        2
    } else {
        1
    }
}

fn pieces(text: &str, wide_cells: bool) -> Vec<(Kind, Unit)> {
    let mut out = Vec::new();
    let mut markers = String::new();
    for ch in text.chars() {
        match ch {
            '\n' => {
                if !markers.is_empty() {
                    out.push((
                        Kind::Word,
                        Unit {
                            text: std::mem::take(&mut markers),
                            width: 0,
                        },
                    ));
                }
                out.push((Kind::Break, Unit::default()));
            }
            ch if matches!(ch as u32, DIM_ON | DIM_OFF) => markers.push(ch),
            ch => {
                let mut unit_text = std::mem::take(&mut markers);
                unit_text.push(ch);
                let kind = if ch == ' ' || ch == '\t' {
                    Kind::Space
                } else {
                    Kind::Word
                };
                let width = char_cells(ch, wide_cells);
                out.push((
                    kind,
                    Unit {
                        text: unit_text,
                        width,
                    },
                ));
            }
        }
    }
    if !markers.is_empty() {
        out.push((
            Kind::Word,
            Unit {
                text: markers,
                width: 0,
            },
        ));
    }
    out
}

fn tokenize(text: &str, wide_cells: bool) -> Vec<Token> {
    let mut tokens: Vec<Token> = Vec::new();
    for (kind, unit) in pieces(text, wide_cells) {
        match tokens.last_mut() {
            Some(token) if token.kind == kind && kind != Kind::Break => {
                token.width += unit.width;
                token.units.push(unit);
            }
            _ => tokens.push(Token {
                width: unit.width,
                units: vec![unit],
                kind,
            }),
        }
    }
    tokens
}

fn push_line(lines: &mut Vec<Line>, cur: &mut Line) {
    let mut line = std::mem::take(cur);
    let kept = line.text.trim_end_matches(' ').len();
    line.width = line.width.saturating_sub(line.text.len() - kept);
    line.text.truncate(kept);
    lines.push(line);
}

fn append_units(cur: &mut Line, units: &[Unit]) {
    for unit in units {
        cur.text.push_str(&unit.text);
        cur.width += unit.width;
    }
}

fn append_word(lines: &mut Vec<Line>, cur: &mut Line, units: &[Unit], width: usize) {
    for unit in units {
        if cur.width > 0 && cur.width + unit.width > width {
            push_line(lines, cur);
        }
        cur.text.push_str(&unit.text);
        cur.width += unit.width;
    }
}

pub fn wrap(text: &str, width: usize, wide_cells: bool) -> Vec<Line> {
    let width = width.max(1);
    let mut lines = Vec::new();
    let mut cur = Line::default();
    for token in tokenize(text, wide_cells) {
        match token.kind {
            Kind::Break => push_line(&mut lines, &mut cur),
            Kind::Space => {
                if cur.width + token.width <= width {
                    append_units(&mut cur, &token.units);
                } else if cur.width > 0 {
                    push_line(&mut lines, &mut cur);
                }
            }
            Kind::Word => {
                if cur.width + token.width <= width {
                    append_units(&mut cur, &token.units);
                } else if cur.width == 0 {
                    append_word(&mut lines, &mut cur, &token.units, width);
                } else {
                    push_line(&mut lines, &mut cur);
                    append_word(&mut lines, &mut cur, &token.units, width);
                }
            }
        }
    }
    push_line(&mut lines, &mut cur);
    lines
}

pub fn paginate(
    line_count: usize,
    per_page: usize,
    max_frames: usize,
) -> (Vec<Range<usize>>, bool) {
    let per_page = per_page.max(1);
    let total = line_count.max(1);
    let pages = total.div_ceil(per_page);
    if pages <= max_frames {
        let frames = (0..pages)
            .map(|page| {
                let start = page * per_page;
                start..(start + per_page).min(total)
            })
            .collect();
        return (frames, false);
    }
    let mut frames: Vec<Range<usize>> = (0..max_frames.saturating_sub(1))
        .map(|page| {
            let start = page * per_page;
            start..(start + per_page).min(total)
        })
        .collect();
    frames.push(total - per_page..total);
    (frames, true)
}
