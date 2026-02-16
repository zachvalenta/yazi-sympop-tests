// Sample Rust file for testing

pub struct MyStruct {
    pub value: i32,
}

impl MyStruct {
    pub fn new() -> Self {
        Self { value: 0 }
    }

    pub fn get_value(&self) -> i32 {
        self.value
    }

    fn private_method(&mut self) {
        self.value += 1;
    }
}

pub enum MyEnum {
    Variant1,
    Variant2(i32),
}

fn top_level_function() {
    println!("top level");
}

pub fn public_function() {
    println!("public");
}
