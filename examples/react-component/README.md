# React Button Component Example

This example shows how to use Ralph to build a reusable React button component.

## Stories

1. **S1: Setup React project** - Initialize with TypeScript
2. **S2: Base Button** - Create basic button component
3. **S3: Variants** - Add primary, secondary, danger variants
4. **S4: Sizes** - Add small, medium, large sizes
5. **S5: Disabled state** - Add disabled prop

## Expected File Structure

After Ralph completes:

```
react-component/
├── package.json
├── tsconfig.json
├── src/
│   ├── components/
│   │   ├── Button.tsx
│   │   └── Button.test.tsx
│   └── index.tsx
├── prd.json
├── prompt.md
└── progress.txt
```

## Running This Example

```bash
cd examples/react-component
ralph-init
# The prd.json is already set up
ralph
```

## Component Usage

```tsx
import { Button } from './components/Button';

// Basic usage
<Button onClick={handleClick}>Click me</Button>

// With variants
<Button variant="primary">Primary</Button>
<Button variant="secondary">Secondary</Button>
<Button variant="danger">Danger</Button>

// With sizes
<Button size="small">Small</Button>
<Button size="medium">Medium</Button>
<Button size="large">Large</Button>

// Disabled
<Button disabled>Disabled</Button>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| children | ReactNode | - | Button content |
| variant | 'primary' \| 'secondary' \| 'danger' | 'primary' | Visual style |
| size | 'small' \| 'medium' \| 'large' | 'medium' | Button size |
| disabled | boolean | false | Disable interaction |
| onClick | () => void | - | Click handler |
