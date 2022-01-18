## statustimers custom theme format

statustimers support the use of custom icon themes matching the following specification:

- one folder per theme
- one file per status icon named after the status ID (1 ... 639)
- supported formats:

  - png with transparent background
  - jpg with black background
  - bmp with black background

A sample theme called 'kupo' would look like this:

```
themes/
 +-- kupo/
      +-- 1.bmp   -- icon for status ID 1
      +-- 2.bmp   -- icon for status ID 2
      ...
      +-- 639.bmp -- icon for status ID 639
```

Themes can be selected from the dropdown box in the statustimers settings ui.
