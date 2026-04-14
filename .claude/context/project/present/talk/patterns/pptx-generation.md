# PPTX Generation Patterns (python-pptx)

API patterns for generating PowerPoint (.pptx) presentations programmatically. Use these patterns when the pptx-assembly-agent assembles PPTX output instead of Slidev markdown.

## 1. Imports and Setup

```python
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
import json

# Load theme mappings
with open("theme_mappings.json") as f:
    THEMES = json.load(f)

def get_theme(name="academic-clean"):
    """Return theme constants dict. Valid names: academic-clean, clinical-teal, ucsf-institutional."""
    return THEMES[name]
```

### Presentation Initialization

```python
def create_presentation(theme_name="academic-clean"):
    """Create a 16:9 widescreen presentation with theme applied."""
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    theme = get_theme(theme_name)
    return prs, theme
```

### Helper: Parse Hex Color

```python
def hex_to_rgb(hex_str):
    """Convert '#RRGGBB' to RGBColor."""
    h = hex_str.lstrip("#")
    return RGBColor(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
```

## 2. Slide Creation

Use the Blank layout (index 6) for maximum control over shape placement. All content is positioned programmatically with Inches/Pt coordinates.

```python
def add_blank_slide(prs):
    """Add a blank slide (layout index 6)."""
    layout = prs.slide_layouts[6]
    return prs.slides.add_slide(layout)
```

### Standard Slide with Title

```python
def add_titled_slide(prs, theme, title_text):
    """Add a blank slide with a themed title text box at the top."""
    slide = add_blank_slide(prs)
    typo = theme["typography"]
    palette = theme["palette"]

    # Title text box: full width, positioned at top
    txBox = slide.shapes.add_textbox(
        left=Inches(0.75), top=Inches(0.4),
        width=Inches(11.8), height=Inches(0.8)
    )
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.LEFT
    run = p.add_run()
    run.text = title_text
    run.font.name = typo["heading_font"]
    run.font.size = Pt(typo["heading_size_pt"])
    run.font.bold = typo["heading_bold"]
    run.font.color.rgb = hex_to_rgb(palette["heading"])

    return slide
```

### Section Divider Slide

```python
def add_section_slide(prs, theme, section_title, subtitle=""):
    """Add a centered section divider slide."""
    slide = add_blank_slide(prs)
    palette = theme["palette"]
    typo = theme["typography"]

    # Centered title
    txBox = slide.shapes.add_textbox(
        left=Inches(2.0), top=Inches(2.5),
        width=Inches(9.3), height=Inches(1.5)
    )
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    run = p.add_run()
    run.text = section_title
    run.font.name = typo["heading_font"]
    run.font.size = Pt(36)
    run.font.bold = True
    run.font.color.rgb = hex_to_rgb(palette["heading"])

    if subtitle:
        txBox2 = slide.shapes.add_textbox(
            left=Inches(2.0), top=Inches(4.2),
            width=Inches(9.3), height=Inches(0.8)
        )
        tf2 = txBox2.text_frame
        p2 = tf2.paragraphs[0]
        p2.alignment = PP_ALIGN.CENTER
        run2 = p2.add_run()
        run2.text = subtitle
        run2.font.name = typo["body_font"]
        run2.font.size = Pt(typo["body_size_pt"])
        run2.font.color.rgb = hex_to_rgb(palette["muted"])

    return slide
```

## 3. Theme Application

Theme constants are stored in `theme_mappings.json` (see `templates/pptx-project/theme_mappings.json`). Each theme provides:

| Key | Type | Description |
|-----|------|-------------|
| `palette.*` | hex string | Colors: background, text, heading, accent, accent_light, muted, highlight, success, warning, error |
| `typography.heading_font` | string | First font name from CSS fallback chain (e.g., "Georgia") |
| `typography.body_font` | string | Body text font name |
| `typography.code_font` | string | Monospace font for code/stats |
| `typography.heading_size_pt` | int | Heading size in points (32) |
| `typography.body_size_pt` | int | Body text size in points (18) |
| `typography.caption_size_pt` | int | Caption size in points (14) |
| `typography.heading_bold` | bool | Whether headings are bold |
| `spacing.content_left` | float | Content area left margin in inches |
| `spacing.content_top` | float | Content area top margin in inches |
| `spacing.content_width` | float | Usable content width in inches |
| `spacing.paragraph_space_pt` | int | Space after paragraphs in points |

### Applying Theme to a Run

```python
def apply_heading_style(run, theme):
    """Apply heading font, size, color from theme."""
    typo = theme["typography"]
    run.font.name = typo["heading_font"]
    run.font.size = Pt(typo["heading_size_pt"])
    run.font.bold = typo["heading_bold"]
    run.font.color.rgb = hex_to_rgb(theme["palette"]["heading"])

def apply_body_style(run, theme):
    """Apply body font, size, color from theme."""
    typo = theme["typography"]
    run.font.name = typo["body_font"]
    run.font.size = Pt(typo["body_size_pt"])
    run.font.bold = False
    run.font.color.rgb = hex_to_rgb(theme["palette"]["text"])

def apply_caption_style(run, theme):
    """Apply caption font, size, muted color from theme."""
    typo = theme["typography"]
    run.font.name = typo["body_font"]
    run.font.size = Pt(typo["caption_size_pt"])
    run.font.color.rgb = hex_to_rgb(theme["palette"]["muted"])
```

### Slide Background

```python
def set_slide_background(slide, theme):
    """Set slide background color from theme palette."""
    background = slide.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = hex_to_rgb(theme["palette"]["background"])
```

## 4. Component Patterns

These five helper functions correspond to the Vue components in the Slidev talk library. Each produces equivalent visual output using python-pptx shapes.

### 4.1 DataTable

Renders a formatted data table with optional header highlighting and caption. Equivalent to the `DataTable.vue` component.

```python
def add_pptx_table(slide, theme, headers, rows, left=None, top=None,
                   width=None, caption=None, highlight_row=None):
    """
    Add a themed data table to a slide.

    Args:
        slide: pptx slide object
        theme: theme dict from theme_mappings.json
        headers: list of column header strings
        rows: list of lists (row data)
        left/top/width: position overrides in Inches (defaults from theme spacing)
        caption: optional caption string below table
        highlight_row: 0-based row index to highlight (excludes header)
    """
    palette = theme["palette"]
    typo = theme["typography"]
    sp = theme["spacing"]

    _left = Inches(left or sp["content_left"])
    _top = Inches(top or 2.0)
    _width = Inches(width or sp["content_width"])
    n_rows = len(rows) + 1  # +1 for header
    n_cols = len(headers)
    row_height = Inches(0.45)
    _height = row_height * n_rows

    table_shape = slide.shapes.add_table(
        n_rows, n_cols, _left, _top, _width, _height
    )
    table = table_shape.table

    # --- Header row ---
    for col_idx, header in enumerate(headers):
        cell = table.cell(0, col_idx)
        cell.text = header
        cell.fill.solid()
        cell.fill.fore_color.rgb = hex_to_rgb(palette["accent_light"])
        for para in cell.text_frame.paragraphs:
            para.alignment = PP_ALIGN.LEFT
            for run in para.runs:
                run.font.name = typo["body_font"]
                run.font.size = Pt(14)
                run.font.bold = True
                run.font.color.rgb = hex_to_rgb(palette["heading"])

    # --- Data rows ---
    for row_idx, row_data in enumerate(rows):
        for col_idx, value in enumerate(row_data):
            cell = table.cell(row_idx + 1, col_idx)
            cell.text = str(value)
            # Highlight row if specified
            if highlight_row is not None and row_idx == highlight_row:
                cell.fill.solid()
                cell.fill.fore_color.rgb = hex_to_rgb(palette["accent_light"])
            for para in cell.text_frame.paragraphs:
                for run in para.runs:
                    run.font.name = typo["body_font"]
                    run.font.size = Pt(13)
                    run.font.color.rgb = hex_to_rgb(palette["text"])

    # --- Caption ---
    if caption:
        cap_box = slide.shapes.add_textbox(
            _left, _top + _height + Inches(0.1),
            _width, Inches(0.4)
        )
        p = cap_box.text_frame.paragraphs[0]
        p.alignment = PP_ALIGN.LEFT
        run = p.add_run()
        run.text = caption
        apply_caption_style(run, theme)

    return table_shape
```

### 4.2 FigurePanel

Displays an image with caption and optional source attribution. Equivalent to the `FigurePanel.vue` component.

```python
def add_pptx_figure(slide, theme, image_path, caption=None, source=None,
                    left=None, top=None, max_width=None, max_height=None):
    """
    Add a figure with caption and source to a slide.

    Args:
        slide: pptx slide object
        theme: theme dict
        image_path: path to image file (PNG, JPG, SVG not supported)
        caption: optional caption text
        source: optional source attribution text
        left/top: position in Inches
        max_width/max_height: maximum dimensions in Inches
    """
    sp = theme["spacing"]
    _left = Inches(left or sp["content_left"])
    _top = Inches(top or 1.8)
    _max_w = Inches(max_width or 10.0)
    _max_h = Inches(max_height or 4.5)

    # Add picture -- width constrains, height auto-calculated
    pic = slide.shapes.add_picture(
        image_path, _left, _top, width=_max_w
    )

    # Scale down if exceeds max height
    if pic.height > _max_h:
        ratio = _max_h / pic.height
        pic.width = int(pic.width * ratio)
        pic.height = _max_h

    # Center horizontally
    slide_w = slide.shapes._spTree.getparent().attrib.get("cx", None)
    # Simple centering: offset from left based on remaining space
    total_w = Inches(13.333)
    pic.left = int((total_w - pic.width) / 2)

    img_bottom = pic.top + pic.height

    # Caption below image
    if caption:
        cap_box = slide.shapes.add_textbox(
            _left, img_bottom + Inches(0.15),
            Inches(sp["content_width"]), Inches(0.4)
        )
        p = cap_box.text_frame.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = caption
        apply_caption_style(run, theme)
        img_bottom = cap_box.top + cap_box.height

    # Source below caption
    if source:
        src_box = slide.shapes.add_textbox(
            _left, img_bottom + Inches(0.05),
            Inches(sp["content_width"]), Inches(0.3)
        )
        p = src_box.text_frame.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = f"Source: {source}"
        run.font.name = theme["typography"]["body_font"]
        run.font.size = Pt(11)
        run.font.italic = True
        run.font.color.rgb = hex_to_rgb(theme["palette"]["muted"])

    return pic
```

### 4.3 CitationBlock

Renders a bordered reference box with author, year, journal, and finding. Equivalent to the `CitationBlock.vue` component.

```python
def add_pptx_citation(slide, theme, author, year, journal, finding,
                      left=None, top=None, width=None):
    """
    Add a citation block with left accent border.

    Args:
        slide: pptx slide object
        theme: theme dict
        author: author name(s)
        year: publication year
        journal: journal name
        finding: key finding text
        left/top/width: position/size overrides in Inches
    """
    palette = theme["palette"]
    typo = theme["typography"]
    sp = theme["spacing"]

    _left = Inches(left or sp["content_left"])
    _top = Inches(top or 2.0)
    _width = Inches(width or sp["content_width"])

    # Accent bar (thin rectangle on the left)
    bar = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE,
        _left, _top, Inches(0.06), Inches(1.0)
    )
    bar.fill.solid()
    bar.fill.fore_color.rgb = hex_to_rgb(palette["accent"])
    bar.line.fill.background()  # no outline

    # Text box to the right of the bar
    txBox = slide.shapes.add_textbox(
        _left + Inches(0.2), _top,
        _width - Inches(0.2), Inches(1.0)
    )
    txBox.fill.solid()
    txBox.fill.fore_color.rgb = RGBColor(0xF8, 0xFA, 0xFC)  # light gray bg
    tf = txBox.text_frame
    tf.word_wrap = True

    # Line 1: Author (year, journal)
    p1 = tf.paragraphs[0]
    run_author = p1.add_run()
    run_author.text = author
    run_author.font.name = typo["body_font"]
    run_author.font.size = Pt(14)
    run_author.font.bold = True
    run_author.font.color.rgb = hex_to_rgb(palette["text"])

    run_meta = p1.add_run()
    run_meta.text = f" ({year}, {journal})"
    run_meta.font.name = typo["body_font"]
    run_meta.font.size = Pt(14)
    run_meta.font.color.rgb = hex_to_rgb(palette["muted"])
    run_meta.font.italic = True

    # Line 2: Finding
    p2 = tf.add_paragraph()
    p2.space_before = Pt(6)
    run_finding = p2.add_run()
    run_finding.text = finding
    run_finding.font.name = typo["body_font"]
    run_finding.font.size = Pt(13)
    run_finding.font.italic = True
    run_finding.font.color.rgb = hex_to_rgb(palette["text"])

    return txBox
```

### 4.4 StatResult

Displays a formatted statistical result with color-coded segments. Equivalent to the `StatResult.vue` component.

```python
def add_pptx_stat_result(slide, theme, test_name, value, ci=None,
                         p_value=None, left=None, top=None, width=None):
    """
    Add a formatted statistical result display.

    Args:
        slide: pptx slide object
        theme: theme dict
        test_name: name of the statistical test (e.g., "Hazard Ratio")
        value: primary result value (e.g., "0.73")
        ci: confidence interval string (e.g., "95% CI: 0.58-0.91")
        p_value: p-value string (e.g., "p = 0.005")
        left/top/width: position/size overrides in Inches
    """
    palette = theme["palette"]
    typo = theme["typography"]
    sp = theme["spacing"]

    _left = Inches(left or sp["content_left"])
    _top = Inches(top or 2.0)
    _width = Inches(width or 6.0)

    txBox = slide.shapes.add_textbox(
        _left, _top, _width, Inches(0.6)
    )
    txBox.fill.solid()
    txBox.fill.fore_color.rgb = RGBColor(0xF8, 0xFA, 0xFC)
    tf = txBox.text_frame
    tf.word_wrap = True

    p = tf.paragraphs[0]

    # Test name (bold, code font)
    run_name = p.add_run()
    run_name.text = f"{test_name}: "
    run_name.font.name = typo["code_font"]
    run_name.font.size = Pt(16)
    run_name.font.bold = True
    run_name.font.color.rgb = hex_to_rgb(palette["text"])

    # Value (accent color)
    run_val = p.add_run()
    run_val.text = str(value)
    run_val.font.name = typo["code_font"]
    run_val.font.size = Pt(16)
    run_val.font.bold = True
    run_val.font.color.rgb = hex_to_rgb(palette["accent"])

    # Confidence interval (muted)
    if ci:
        run_ci = p.add_run()
        run_ci.text = f"  {ci}"
        run_ci.font.name = typo["code_font"]
        run_ci.font.size = Pt(14)
        run_ci.font.color.rgb = hex_to_rgb(palette["muted"])

    # P-value (red if significant, muted otherwise)
    if p_value:
        run_p = p.add_run()
        run_p.text = f"  {p_value}"
        run_p.font.name = typo["code_font"]
        run_p.font.size = Pt(14)
        run_p.font.bold = True
        # Parse significance: red if p < 0.05
        try:
            p_num = float(p_value.replace("p = ", "").replace("p < ", "").strip())
            is_sig = p_num < 0.05
        except ValueError:
            is_sig = "<" in p_value
        run_p.font.color.rgb = hex_to_rgb(palette["error"]) if is_sig else hex_to_rgb(palette["muted"])

    return txBox
```

### 4.5 FlowDiagram

Creates a CONSORT-style participant flow diagram using shapes and connectors. Equivalent to the `FlowDiagram.vue` component.

```python
def add_pptx_flow_diagram(slide, theme, stages, exclusions=None):
    """
    Add a CONSORT-style flow diagram.

    Args:
        slide: pptx slide object
        theme: theme dict
        stages: list of dicts with keys: label, n (participant count)
            Example: [{"label": "Enrolled", "n": 500}, {"label": "Randomized", "n": 420}]
        exclusions: list of dicts with keys: after_stage (0-based index), label, n
            Example: [{"after_stage": 0, "label": "Excluded", "n": 80}]
    """
    palette = theme["palette"]
    typo = theme["typography"]

    box_w = Inches(3.0)
    box_h = Inches(0.7)
    gap_y = Inches(0.3)
    start_x = Inches(5.15)  # centered for 13.333" slide
    start_y = Inches(1.2)

    excl_offset_x = Inches(4.0)  # exclusion box to the right
    excl_w = Inches(3.5)
    excl_h = Inches(0.6)

    exclusions = exclusions or []

    shapes_by_stage = []

    for i, stage in enumerate(stages):
        y = start_y + i * (box_h + gap_y)

        # Main stage box (rounded rectangle)
        box = slide.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            start_x, y, box_w, box_h
        )
        box.fill.solid()
        box.fill.fore_color.rgb = hex_to_rgb(palette["accent_light"])
        box.line.color.rgb = hex_to_rgb(palette["accent"])
        box.line.width = Pt(1.5)

        tf = box.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = f"{stage['label']} (n={stage['n']})"
        run.font.name = typo["body_font"]
        run.font.size = Pt(13)
        run.font.bold = True
        run.font.color.rgb = hex_to_rgb(palette["text"])

        shapes_by_stage.append({"box": box, "y": y})

        # Arrow connector to next stage
        if i < len(stages) - 1:
            connector_top = y + box_h
            connector_bottom = y + box_h + gap_y
            # Use a simple line shape as connector
            line = slide.shapes.add_shape(
                MSO_SHAPE.LINE_INVERSE,
                start_x + box_w / 2 - Inches(0.01), connector_top,
                Inches(0.02), gap_y
            )
            line.line.color.rgb = hex_to_rgb(palette["muted"])
            line.line.width = Pt(1.5)

    # Exclusion boxes
    for excl in exclusions:
        idx = excl["after_stage"]
        if idx >= len(shapes_by_stage):
            continue
        ref = shapes_by_stage[idx]
        excl_y = ref["y"] + box_h / 2 - excl_h / 2
        excl_x = start_x + excl_offset_x

        excl_box = slide.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            excl_x, excl_y, excl_w, excl_h
        )
        excl_box.fill.solid()
        excl_box.fill.fore_color.rgb = RGBColor(0xFF, 0xF3, 0xCD)  # warm yellow
        excl_box.line.color.rgb = hex_to_rgb(palette["warning"])
        excl_box.line.width = Pt(1)

        tf = excl_box.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = f"{excl['label']} (n={excl['n']})"
        run.font.name = typo["body_font"]
        run.font.size = Pt(12)
        run.font.color.rgb = hex_to_rgb(palette["text"])

        # Horizontal connector from main box to exclusion
        h_line = slide.shapes.add_shape(
            MSO_SHAPE.LINE_INVERSE,
            start_x + box_w, excl_y + excl_h / 2,
            excl_offset_x - box_w, Inches(0.02)
        )
        h_line.line.color.rgb = hex_to_rgb(palette["muted"])
        h_line.line.width = Pt(1)

    return shapes_by_stage
```

## 5. Speaker Notes

Every slide should include speaker notes with talking points. Notes support plain text only (no formatting in PowerPoint notes pane).

```python
def set_speaker_notes(slide, notes_text):
    """Add speaker notes to a slide. Accepts plain text or newline-separated points."""
    notes_slide = slide.notes_slide
    tf = notes_slide.notes_text_frame
    tf.text = notes_text
```

### Structured Notes Pattern

```python
def set_structured_notes(slide, points, duration_seconds=None):
    """
    Add structured speaker notes with optional timing.

    Args:
        points: list of talking point strings
        duration_seconds: suggested time for this slide
    """
    lines = []
    if duration_seconds:
        lines.append(f"[{duration_seconds}s]")
    for point in points:
        lines.append(f"- {point}")
    set_speaker_notes(slide, "\n".join(lines))
```

## 6. Export

```python
def save_presentation(prs, output_path):
    """Save the presentation to a .pptx file."""
    prs.save(output_path)
```

### Complete Deck Assembly Pattern

```python
def build_deck(theme_name, slides_data, output_path):
    """
    Assemble a complete presentation from structured slide data.

    Args:
        theme_name: one of "academic-clean", "clinical-teal", "ucsf-institutional"
        slides_data: list of dicts, each with "type" and type-specific keys
        output_path: file path for output .pptx
    """
    prs, theme = create_presentation(theme_name)

    for sd in slides_data:
        slide_type = sd["type"]

        if slide_type == "title":
            slide = add_titled_slide(prs, theme, sd["title"])
            # Add subtitle if present
            if "subtitle" in sd:
                txBox = slide.shapes.add_textbox(
                    Inches(0.75), Inches(1.4),
                    Inches(11.8), Inches(0.6)
                )
                p = txBox.text_frame.paragraphs[0]
                run = p.add_run()
                run.text = sd["subtitle"]
                apply_body_style(run, theme)

        elif slide_type == "section":
            slide = add_section_slide(prs, theme, sd["title"], sd.get("subtitle", ""))

        elif slide_type == "content":
            slide = add_titled_slide(prs, theme, sd["title"])
            # Add bullet points
            content_top = 1.6
            for i, bullet in enumerate(sd.get("bullets", [])):
                txBox = slide.shapes.add_textbox(
                    Inches(1.0), Inches(content_top + i * 0.5),
                    Inches(11.0), Inches(0.45)
                )
                p = txBox.text_frame.paragraphs[0]
                run = p.add_run()
                run.text = f"\u2022  {bullet}"
                apply_body_style(run, theme)

        elif slide_type == "table":
            slide = add_titled_slide(prs, theme, sd["title"])
            add_pptx_table(slide, theme, sd["headers"], sd["rows"],
                          caption=sd.get("caption"),
                          highlight_row=sd.get("highlight_row"))

        elif slide_type == "figure":
            slide = add_titled_slide(prs, theme, sd["title"])
            add_pptx_figure(slide, theme, sd["image_path"],
                           caption=sd.get("caption"),
                           source=sd.get("source"))

        elif slide_type == "citation":
            slide = add_titled_slide(prs, theme, sd["title"])
            for j, cite in enumerate(sd.get("citations", [])):
                add_pptx_citation(slide, theme,
                                 cite["author"], cite["year"],
                                 cite["journal"], cite["finding"],
                                 top=2.0 + j * 1.3)

        elif slide_type == "stat":
            slide = add_titled_slide(prs, theme, sd["title"])
            for j, stat in enumerate(sd.get("stats", [])):
                add_pptx_stat_result(slide, theme,
                                    stat["test_name"], stat["value"],
                                    ci=stat.get("ci"),
                                    p_value=stat.get("p_value"),
                                    top=2.0 + j * 0.8)

        elif slide_type == "flow":
            slide = add_titled_slide(prs, theme, sd["title"])
            add_pptx_flow_diagram(slide, theme,
                                 sd["stages"],
                                 exclusions=sd.get("exclusions"))

        # Speaker notes
        if "notes" in sd:
            set_speaker_notes(slide, sd["notes"])

    save_presentation(prs, output_path)
    return output_path
```

## 7. Error Handling

### Missing Images

```python
import os

def safe_add_picture(slide, theme, image_path, **kwargs):
    """Add picture with fallback placeholder if image is missing."""
    if os.path.exists(image_path):
        return add_pptx_figure(slide, theme, image_path, **kwargs)
    else:
        # Create a placeholder rectangle with "Image not found" text
        sp = theme["spacing"]
        _left = Inches(kwargs.get("left", sp["content_left"]))
        _top = Inches(kwargs.get("top", 1.8))
        placeholder = slide.shapes.add_shape(
            MSO_SHAPE.RECTANGLE,
            _left, _top, Inches(8.0), Inches(4.0)
        )
        placeholder.fill.solid()
        placeholder.fill.fore_color.rgb = RGBColor(0xF3, 0xF4, 0xF6)
        placeholder.line.color.rgb = RGBColor(0xD1, 0xD5, 0xDB)

        tf = placeholder.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = f"[Image not found: {os.path.basename(image_path)}]"
        run.font.name = theme["typography"]["body_font"]
        run.font.size = Pt(14)
        run.font.color.rgb = hex_to_rgb(theme["palette"]["muted"])

        return placeholder
```

### Font Fallback

python-pptx embeds font names as strings. If the specified font is not available on the viewing system, PowerPoint uses its own fallback. The theme_mappings.json uses the first font from each CSS fallback chain:

| Theme | Heading Font | Body Font | Code Font |
|-------|-------------|-----------|-----------|
| academic-clean | Georgia | Helvetica Neue | Courier New |
| clinical-teal | Segoe UI | Segoe UI | Courier New |
| ucsf-institutional | Garamond | Arial | Courier New |

For maximum cross-platform compatibility, prefer: Arial (body), Georgia (headings), Courier New (code). These are available on Windows, macOS, and most Linux distributions with Microsoft fonts installed.

### Table Overflow

For tables with many rows that may exceed slide height:

```python
def add_pptx_table_paginated(prs, theme, title, headers, rows,
                             caption=None, max_rows_per_slide=8):
    """Split a large table across multiple slides."""
    slides = []
    for i in range(0, len(rows), max_rows_per_slide):
        chunk = rows[i:i + max_rows_per_slide]
        page_num = i // max_rows_per_slide + 1
        total_pages = (len(rows) + max_rows_per_slide - 1) // max_rows_per_slide

        slide_title = title
        if total_pages > 1:
            slide_title = f"{title} ({page_num}/{total_pages})"

        slide = add_titled_slide(prs, theme, slide_title)
        add_pptx_table(slide, theme, headers, chunk,
                      caption=caption if i + max_rows_per_slide >= len(rows) else None)
        slides.append(slide)

    return slides
```

## Dependencies

- `python-pptx >= 1.0.0` -- Install with `pip install python-pptx`
- Python 3.8+
- Images must be PNG, JPEG, GIF, BMP, or TIFF (SVG not supported by python-pptx)

## Related Files

- `templates/pptx-project/theme_mappings.json` -- Theme constants for all three themes
- `templates/pptx-project/generate_deck.py` -- Skeleton generation script
- `templates/pptx-project/README.md` -- Usage instructions
- `components/DataTable.vue` -- Slidev equivalent of `add_pptx_table()`
- `components/FigurePanel.vue` -- Slidev equivalent of `add_pptx_figure()`
- `components/CitationBlock.vue` -- Slidev equivalent of `add_pptx_citation()`
- `components/StatResult.vue` -- Slidev equivalent of `add_pptx_stat_result()`
- `components/FlowDiagram.vue` -- Slidev equivalent of `add_pptx_flow_diagram()`
