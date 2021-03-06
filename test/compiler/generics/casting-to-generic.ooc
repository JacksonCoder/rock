
//! shouldfail

// Test for https://github.com/ooc-lang/rock/issues/891

Peeker: class {
    inner: Object
    init: func (=inner)
    peek: func <T> (T: Class) -> T {
        inner as T
    }
}

describe("casting to generic is forbidden", ||
    p := Peeker new("hi!")
    expect("hi!", p peek(String))
)
