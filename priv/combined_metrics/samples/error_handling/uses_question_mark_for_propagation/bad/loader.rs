use std::fs;
use std::io;
use std::path::Path;

pub struct FileRecord {
    pub path: String,
    pub lines: Vec<String>,
    pub byte_count: usize,
}

pub fn load_record(path: &Path) -> Result<FileRecord, String> {
    // Manual match instead of ? operator — noisy and error-prone
    let raw = match fs::read(path) {
        Ok(bytes) => bytes,
        Err(e) => return Err(format!("IO error: {e}")),
    };

    let content = match String::from_utf8(raw.clone()) {
        Ok(s) => s,
        Err(e) => return Err(format!("encoding error: {e}")),
    };

    if content.trim().is_empty() {
        return Err(format!("file is empty: {}", path.display()));
    }

    let lines: Vec<String> = content.lines().map(str::to_string).collect();

    Ok(FileRecord {
        path: path.display().to_string(),
        lines,
        byte_count: raw.len(),
    })
}

pub fn load_all(dir: &Path) -> Result<Vec<FileRecord>, String> {
    let read_dir = match fs::read_dir(dir) {
        Ok(rd) => rd,
        Err(e) => return Err(format!("cannot read dir: {e}")),
    };

    let mut records = Vec::new();
    for entry_result in read_dir {
        let entry = match entry_result {
            Ok(e) => e,
            Err(e) => return Err(format!("dir entry error: {e}")),
        };
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some("txt") {
            let record = match load_record(&path) {
                Ok(r) => r,
                Err(e) => return Err(e),
            };
            records.push(record);
        }
    }
    Ok(records)
}
