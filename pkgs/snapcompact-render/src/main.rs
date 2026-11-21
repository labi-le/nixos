use std::{
    env, fs,
    path::{Path, PathBuf},
    process::ExitCode,
};

use anyhow::{bail, Context, Result};
use snapcompact_render::{build, RenderRequest};

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("snapcompact-render: {err:#}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<()> {
    let (request_path, out_dir) = parse_args()?;
    let raw = fs::read_to_string(&request_path)
        .with_context(|| format!("cannot read request {}", request_path.display()))?;
    let request: RenderRequest = serde_json::from_str(&raw)
        .with_context(|| format!("cannot parse {}", request_path.display()))?;
    let frames = build(&request)?;
    fs::create_dir_all(&out_dir).with_context(|| format!("cannot create {}", out_dir.display()))?;
    for frame in &frames.frames {
        fs::write(out_dir.join(&frame.file), &frame.png)
            .with_context(|| format!("cannot write {}", frame.file))?;
    }
    let manifest = serde_json::to_string_pretty(&frames.manifest())?;
    fs::write(out_dir.join("manifest.json"), format!("{manifest}\n"))
        .with_context(|| "cannot write manifest.json".to_string())?;
    Ok(())
}

fn parse_args() -> Result<(PathBuf, PathBuf)> {
    let mut args = env::args_os().skip(1);
    let Some(request) = args.next() else {
        bail!("usage: snapcompact-render <req.json> <out-dir>");
    };
    let Some(out_dir) = args.next() else {
        bail!("usage: snapcompact-render <req.json> <out-dir>");
    };
    if args.next().is_some() {
        bail!("usage: snapcompact-render <req.json> <out-dir>");
    }
    Ok((
        Path::new(&request).to_path_buf(),
        Path::new(&out_dir).to_path_buf(),
    ))
}
