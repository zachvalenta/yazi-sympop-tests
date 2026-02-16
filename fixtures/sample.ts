// Sample TypeScript file for testing

function topLevelFunction(): void {
  console.log('top level');
}

class MyClass {
  private value: number;

  constructor() {
    this.value = 0;
  }

  methodOne(): number {
    return this.value;
  }

  methodTwo(arg: number): void {
    this.value = arg;
  }
}

const arrowFunc = (): void => {
  console.log('arrow');
};

export function exportedFunction(): string {
  return 'exported';
}

interface MyInterface {
  prop: string;
}
