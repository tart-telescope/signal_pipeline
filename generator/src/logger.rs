use flexi_logger::{
    style, Age, Cleanup, Criterion, DeferredNow, FileSpec, Logger, Naming,
    WriteMode,
};
use log::{debug, Level, Record};

pub fn configure(
    level: &str,
    verbose: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let dir = "logs";
    let days = 1;
    let dup = if verbose {
        flexi_logger::Duplicate::All
    } else {
        flexi_logger::Duplicate::Warn
    };
    Logger::try_with_str(level)?
        .log_to_file(FileSpec::default().directory(dir.clone()))
        .duplicate_to_stdout(dup)
        .write_mode(WriteMode::BufferAndFlush)
        .format(colour_format)
        .rotate(
            Criterion::Age(Age::Day),
            Naming::Timestamps,
            Cleanup::KeepLogFiles(days),
        )
        .start()?;
    debug!("Logging to directory: {}", dir);
    Ok(())
}

fn colour_format(
    out: &mut dyn std::io::Write,
    now: &mut DeferredNow,
    rec: &Record,
) -> Result<(), std::io::Error> {
    let level = rec.level();
    write!(
        out,
        "[{}] {} {}:{}: {}",
        style(Level::Debug)
            .paint(now.format("%Y-%m-%d %H:%M:%S%.3f %:z").to_string()),
        style(level).paint(rec.level().to_string()),
        rec.file().unwrap_or("<unknown>"),
        rec.line().unwrap_or(0),
        style(level).paint(&rec.args().to_string())
    )
}
