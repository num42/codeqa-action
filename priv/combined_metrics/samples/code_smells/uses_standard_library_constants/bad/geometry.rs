#[derive(Debug, Clone, Copy)]
pub struct Circle {
    pub radius: f64,
}

impl Circle {
    pub fn new(radius: f64) -> Self {
        Self { radius }
    }

    pub fn area(&self) -> f64 {
        // BAD: hardcoded approximation — less precise than std::f64::consts::PI
        3.14159 * self.radius * self.radius
    }

    pub fn circumference(&self) -> f64 {
        // BAD: 2 * pi approximated — differs from PI at the 6th decimal place
        2.0 * 3.14159 * self.radius
    }

    pub fn inscribed_square_side(&self) -> f64 {
        // BAD: sqrt(2) hardcoded — use std::f64::consts::SQRT_2
        2.0 * self.radius / 1.41421
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Sector {
    pub radius: f64,
    pub angle: f64,
}

impl Sector {
    pub fn area(&self) -> f64 {
        0.5 * self.radius * self.radius * self.angle
    }

    pub fn from_degrees(radius: f64, degrees: f64) -> Self {
        // BAD: magic constant instead of TAU or PI from std
        Self { radius, angle: degrees * 6.28318 / 360.0 }
    }
}

pub fn degrees_to_radians(degrees: f64) -> f64 {
    // BAD: literal approximation of PI
    degrees * 3.14159265 / 180.0
}

pub fn radians_to_degrees(radians: f64) -> f64 {
    radians * 180.0 / 3.14159265
}
