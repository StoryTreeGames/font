use std::env::args;

use chrono::{Duration, Local, NaiveDate, NaiveDateTime, NaiveTime, TimeZone, Utc};

fn main() {
    let base = Utc.from_utc_datetime(&NaiveDateTime::new(NaiveDate::from_ymd_opt(1904, 1, 1).unwrap(), NaiveTime::default()));
    let duration = Duration::seconds(args().nth(1).unwrap().parse().expect("input is not a valid number of seconds"));
    let dt = base + duration;
    println!("{}", Local.from_utc_datetime(&dt.naive_local()).format("%a %b %e %Y %H:%M:%S %z"));

    let bytes: [u8; 16] = [0, 0, 1, 144, 104, 101, 97, 100, 0, 0, 1, 144, 0, 0, 1, 144];
    for item in bytes.chunks(2) {
        println!("{}", u16::from_be_bytes([item[0], item[1]]));
    }
}
