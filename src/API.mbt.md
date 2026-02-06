# API Documentation

This file contains executable doc tests using `mbt test` blocks.

## version

Return current library version string.

```mbt check
///|
test {
  inspect(version(), content="0.1.0")
}
```
