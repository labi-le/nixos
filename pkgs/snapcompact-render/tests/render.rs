use std::{fs, path::PathBuf, process::Command};

use snapcompact_render::{
    build,
    fonts::resolve_font,
    render::is_wide,
    select_font,
    wrap::{paginate, wrap},
    Manifest, RenderRequest,
};

fn request(text: &str) -> RenderRequest {
    RenderRequest {
        text: text.to_string(),
        ..RenderRequest::default()
    }
}

fn scratch(name: &str) -> PathBuf {
    let dir =
        std::env::temp_dir().join(format!("snapcompact-render-{}-{name}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    dir
}

#[test]
fn wrap_breaks_on_word_boundaries() {
    let lines = wrap("alpha beta gamma delta", 10, false);
    let texts: Vec<&str> = lines.iter().map(|line| line.text.as_str()).collect();
    assert_eq!(texts, ["alpha beta", "gamma", "delta"]);
    assert!(lines.iter().all(|line| line.width <= 10));
}

#[test]
fn wrap_hard_splits_words_longer_than_a_line() {
    let lines = wrap("abcdefghij", 4, false);
    let texts: Vec<&str> = lines.iter().map(|line| line.text.as_str()).collect();
    assert_eq!(texts, ["abcd", "efgh", "ij"]);
}

#[test]
fn wrap_keeps_dim_markers_attached_to_their_span() {
    let text = "ab\u{e}cd\u{f}efgh";
    let lines = wrap(text, 3, false);
    assert!(lines.len() > 1);
    for line in &lines {
        assert!(
            !line.text.ends_with('\u{e}'),
            "dim-on marker split off: {:?}",
            line.text
        );
        assert!(
            !line.text.ends_with('\u{f}'),
            "dim-off marker split off: {:?}",
            line.text
        );
    }
    let rejoined: String = lines.iter().map(|line| line.text.as_str()).collect();
    assert!(
        rejoined.contains("\u{e}cd"),
        "dim span must survive wrapping"
    );
}

#[test]
fn wrap_counts_wide_cells() {
    let lines = wrap("你好世界", 4, true);
    assert_eq!(lines.len(), 2);
    assert!(lines.iter().all(|line| line.width == 4));
    let narrow = wrap("你好世界", 4, false);
    assert_eq!(narrow.len(), 1);
    assert!(is_wide('你' as u32));
}

#[test]
fn wrap_keeps_indentation_that_fits() {
    let lines = wrap("    indented line", 40, false);
    assert_eq!(lines[0].text, "    indented line");
}

#[test]
fn paginate_splits_full_pages() {
    let (frames, truncated) = paginate(5, 3, 10);
    assert_eq!(frames, vec![0..3, 3..5]);
    assert!(!truncated);
}

#[test]
fn paginate_keeps_the_tail_when_over_max_frames() {
    let (frames, truncated) = paginate(10, 3, 2);
    assert!(truncated);
    assert_eq!(frames, vec![0..3, 7..10]);
}

#[test]
fn paginate_with_single_frame_keeps_only_the_tail() {
    let (frames, truncated) = paginate(10, 3, 1);
    assert!(truncated);
    assert_eq!(frames, vec![7..10]);
}

#[test]
fn cyrillic_text_renders_with_the_8x13_font() {
    let font = resolve_font("8x13").expect("8x13 is bundled");
    assert!(font.supports_text("Привет, мир! Съешь ещё этих мягких французских булок."));
    let (name, _) = select_font(&request("Привет, мир! Тест.")).unwrap();
    assert_eq!(name, "8x13");
}

#[test]
fn unknown_font_names_fall_back_to_silver() {
    let mut req = request("text");
    req.font = "nope".to_string();
    let (name, _) = select_font(&req).unwrap();
    assert_eq!(name, "silver");
}

#[test]
fn uncovered_glyphs_keep_the_bitmap_grid() {
    let (name, _) = select_font(&request("Привет 你好")).unwrap();
    assert_eq!(name, "8x13");
    let set = build(&request("Привет 你好")).unwrap();
    assert_eq!(set.font, "8x13");
    assert_eq!(set.frames[0].png[25], 3, "bitmap shapes must stay indexed");
}

#[test]
fn short_archive_produces_one_indexed_frame() {
    let set = build(&request("Hello world. Again.")).unwrap();
    assert_eq!(set.font, "8x13");
    assert!(!set.truncated);
    assert_eq!(set.frames.len(), 1);
    let frame = &set.frames[0];
    assert_eq!(frame.file, "frame-000.png");
    assert_eq!(frame.width, 1568);
    assert_eq!(frame.height, 64);
    assert_eq!(frame.chars, 19);
    assert_eq!(
        frame.png[..8],
        [0x89, b'P', b'N', b'G', 0x0d, 0x0a, 0x1a, 0x0a]
    );
    assert_eq!(frame.png[25], 3, "bitmap shapes must encode indexed");
    assert_eq!(frame.png[24], 1, "bw frame narrows to a 1-bit palette");
}

#[test]
fn silver_frames_encode_rgb() {
    let mut req = request("Привет 你好");
    req.font = "silver".to_string();
    let set = build(&req).unwrap();
    assert_eq!(set.font, "silver");
    let frame = &set.frames[0];
    assert_eq!(frame.png[25], 2, "silver frames must encode RGB");
    assert_eq!(frame.width, 1568);
}

#[test]
fn empty_archive_still_produces_one_blank_frame() {
    let set = build(&request("")).unwrap();
    assert_eq!(set.frames.len(), 1);
    assert_eq!(set.frames[0].chars, 0);
    assert_eq!(set.frames[0].height, 64);
}

#[test]
fn long_archive_truncates_and_keeps_the_tail() {
    let body: String = (0..4000)
        .map(|i| format!("line {i} of the archive. "))
        .collect();
    let lines = wrap(&body, 1568 / 8, true);
    let per_page = 1568 / 13;
    assert!(lines.len() > per_page * 3);
    let set = build(&RenderRequest {
        text: body.clone(),
        max_frames: 3,
        ..RenderRequest::default()
    })
    .unwrap();
    assert!(set.truncated);
    assert_eq!(set.frames.len(), 3);
    let page_chars = |range: std::ops::Range<usize>| -> usize {
        lines[range]
            .iter()
            .map(|line| line.text.chars().count())
            .sum()
    };
    assert_eq!(set.frames[0].chars, page_chars(0..per_page));
    assert_eq!(set.frames[1].chars, page_chars(per_page..per_page * 2));
    assert_eq!(
        set.frames[2].chars,
        page_chars(lines.len() - per_page..lines.len()),
        "last frame must carry the tail of the archive"
    );
    assert!(
        set.frames.iter().map(|frame| frame.chars).sum::<usize>() < body.chars().count(),
        "dropped middle pages must not be re-rendered"
    );
}

#[test]
fn pagination_respects_the_cell_grid() {
    let size = 130u32;
    let cols = (size / 8) as usize;
    let rows = (size / 13) as usize;
    let text = "x".repeat(cols * rows + 3);
    let set = build(&RenderRequest {
        text,
        size,
        ..RenderRequest::default()
    })
    .unwrap();
    assert_eq!(set.frames.len(), 2);
    assert_eq!(set.frames[0].chars, cols * rows);
    assert_eq!(set.frames[0].height, (rows * 13) as u32);
    assert_eq!(set.frames[1].chars, 3);
    assert_eq!(set.frames[1].height, 64);
}

#[test]
fn rendering_is_deterministic() {
    let first = build(&request("Repeatable output. Same bytes.")).unwrap();
    let second = build(&request("Repeatable output. Same bytes.")).unwrap();
    assert_eq!(first.frames[0].png, second.frames[0].png);
}

#[test]
fn cli_writes_frames_and_manifest() {
    let dir = scratch("cli");
    let req_path = dir.join("req.json");
    let out_dir = dir.join("out");
    fs::write(
        &req_path,
        r#"{"text":"Hello. Привет.","size":512,"max_frames":2}"#,
    )
    .unwrap();
    let status = Command::new(env!("CARGO_BIN_EXE_snapcompact-render"))
        .arg(&req_path)
        .arg(&out_dir)
        .status()
        .unwrap();
    assert!(status.success());

    let manifest: Manifest =
        serde_json::from_str(&fs::read_to_string(out_dir.join("manifest.json")).unwrap()).unwrap();
    assert_eq!(manifest.font, "8x13");
    assert!(!manifest.truncated);
    assert_eq!(manifest.frames.len(), 1);
    let entry = &manifest.frames[0];
    assert_eq!(entry.file, "frame-000.png");
    assert_eq!(entry.width, 512);
    let png = fs::read(out_dir.join(&entry.file)).unwrap();
    assert_eq!(png[..4], [0x89, b'P', b'N', b'G']);
    let width = u32::from_be_bytes(png[16..20].try_into().unwrap());
    let height = u32::from_be_bytes(png[20..24].try_into().unwrap());
    assert_eq!((width, height), (entry.width, entry.height));
    let _ = fs::remove_dir_all(&dir);
}

#[test]
fn cli_rejects_bad_arguments() {
    let dir = scratch("bad-args");
    let status = Command::new(env!("CARGO_BIN_EXE_snapcompact-render"))
        .arg("only-one")
        .status()
        .unwrap();
    assert_eq!(status.code(), Some(1));

    let req_path = dir.join("req.json");
    fs::write(&req_path, r#"{"text":"x","variant":"zebra"}"#).unwrap();
    let status = Command::new(env!("CARGO_BIN_EXE_snapcompact-render"))
        .arg(&req_path)
        .arg(dir.join("out"))
        .status()
        .unwrap();
    assert_eq!(status.code(), Some(1));
    let _ = fs::remove_dir_all(&dir);
}

#[test]
fn defaults_match_the_contract() {
    let req = RenderRequest::default();
    assert_eq!(req.size, 1568);
    assert_eq!(req.font, "8x13");
    assert_eq!(req.fallback_font, "silver");
    assert_eq!(req.variant, "bw");
    assert_eq!(req.columns, 1);
    assert_eq!(req.max_frames, 40);
}

#[test]
fn two_column_shape_flows_lines_into_both_columns() {
    let text: String = (0..40)
        .map(|i| format!("ab{i}"))
        .collect::<Vec<_>>()
        .join("\n");
    let set = build(&RenderRequest {
        text,
        columns: 2,
        size: 260,
        ..RenderRequest::default()
    })
    .unwrap();
    assert_eq!(set.font, "8x13");
    assert_eq!(set.frames.len(), 1);
    assert_eq!(set.frames[0].width, 260);
    assert_eq!(set.frames[0].height, 260);
}
