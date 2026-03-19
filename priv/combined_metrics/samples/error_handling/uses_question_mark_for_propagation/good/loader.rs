use std::fs;
use std::io;
use std::path::Path;

#[derive(Debug)]
pub enum LoadError {
    Io(io::Error),
    InvalidEncoding(String),
    EmptyFile(String),
}

impl From<io::Error> for LoadError {
    fn from(e: io::Error) -> Self {
        LoadError::Io(e)
    }
}

impl std::fmt::Display for LoadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LoadError::Io(e) => write!(f, "IO error: {e}"),
            LoadError::InvalidEncoding(msg) => write!(f, "encoding error: {msg}"),
            LoadError::EmptyFile(path) => write!(f, "file is empty: {path}"),
        }
    }
}

pub struct FileRecord {
    pub path: String,
    pub lines: Vec<String>,
    pub byte_count: usize,
}

pub fn load_record(path: &Path) -> Result<FileRecord, LoadError> {
    let raw = fs::read(path)?;
    let content = String::from_utf8(raw.clone()).map_err(|e| {
        LoadError::InvalidEncoding(format!("{}: {e}", path.display()))
    })?;

    if content.trim().is_empty() {
        return Err(LoadError::EmptyFile(path.display().to_string()));
    }

    let lines: Vec<String> = content.lines().map(str::to_string).collect();

    Ok(FileRecord {
        path: path.display().to_string(),
        lines,
        byte_count: raw.len(),
    })
}

pub fn load_all(dir: &Path) -> Result<Vec<FileRecord>, LoadError> {
    let mut records = Vec::new();
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some("txt") {
            records.push(load_record(&path)?);
        }
    }
    Ok(records)
}
