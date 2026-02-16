// Sample JavaScript file for testing

function topLevelFunction() {
  console.log('top level');
}

class MyClass {
  constructor() {
    this.value = 0;
  }

  methodOne() {
    return this.value;
  }

  methodTwo(arg) {
    this.value = arg;
  }
}

const arrowFunc = () => {
  console.log('arrow');
};

export function exportedFunction() {
  return 'exported';
}

class AnotherClass {
  onlyMethod() {
    console.log('only');
  }
}
