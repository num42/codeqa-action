use std::f64::consts::{PI, SQRT_2, TAU};

#[derive(Debug, Clone, Copy)]
pub struct Circle {
    pub radius: f64,
}

impl Circle {
    pub fn new(radius: f64) -> Self {
        Self { radius }
    }

    pub fn area(&self) -> f64 {
        PI * self.radius * self.radius
    }

    pub fn circumference(&self) -> f64 {
        TAU * self.radius
    }

    pub fn inscribed_square_diagonal(&self) -> f64 {
        // Diameter * sqrt(2) / sqrt(2) == diameter, but demonstrates SQRT_2 usage
        2.0 * self.radius / SQRT_2 * SQRT_2
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Sector {
    pub radius: f64,
    /// angle in radians
    pub angle: f64,
}

impl Sector {
    pub fn arc_length(&self) -> f64 {
        self.radius * self.angle
    }

    pub fn area(&self) -> f64 {
        0.5 * self.radius * self.radius * self.angle
    }

    pub fn from_degrees(radius: f64, degrees: f64) -> Self {
        // TAU / 360.0 is exact; using PI * 2.0 / 360.0 would also work
        Self { radius, angle: degrees * TAU / 360.0 }
    }
}

pub fn degrees_to_radians(degrees: f64) -> f64 {
    degrees * PI / 180.0
}

pub fn radians_to_degrees(radians: f64) -> f64 {
    radians * 180.0 / PI
}
