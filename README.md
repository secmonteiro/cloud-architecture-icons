# cloud-architecture-icons

Custom draw.io / diagrams.net library for the cloud architecture SVG icons in this repository.

## Import in draw.io

Use the generated library file at the repository root when you want to import every icon at once:

```text
cloud-architecture-icons.xml
```

Use the categorized libraries when you want to import only one section:

```text
Azure/XML/
```

Examples:

```text
Azure/XML/Azure - Networking.xml
Azure/XML/Azure - Security.xml
Azure/XML/Azure - Identity.xml
Azure/XML/Microsoft Entra - Color Icons.xml
Azure/XML/Dynamics 365 - App Icons.xml
Azure/XML/Power Platform.xml
```

In draw.io / diagrams.net:

1. Open the editor.
2. Go to `File > Open Library From > GitHub`.
3. Select this repository.
4. Open `cloud-architecture-icons.xml` for the complete library, or open one XML from `Azure/XML` for a categorized library.

Each library embeds its SVG icons as base64 SVG data URIs, so draw.io imports the selected icon set from a single XML file.

You can also load it directly with the `clibs` URL parameter:

```text
https://app.diagrams.net/?clibs=Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fsecmonteiro%2Fcloud-architecture-icons%2Fmain%2Fcloud-architecture-icons.xml
```

## Update the library

After adding or changing SVG files, regenerate the XML:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-drawio-library.ps1
```

The script scans all `.svg` files, keeps the original SVG files untouched, and writes a fresh `cloud-architecture-icons.xml`.
It also writes categorized XML libraries to `Azure/XML`.

## Import in Lucidchart

Use the generated Lucidchart shape library package:

```text
Azure/Lucidchart/cloud-architecture-icons.lcsl
```

In Lucidchart:

1. Open a document.
2. Click `More shapes` at the bottom of the Shapes panel.
3. Click `Import Shapes`.
4. Select `Azure/Lucidchart/cloud-architecture-icons.lcsl`.

The `.lcsl` package is a ZIP-style Lucid shape library with:

```text
library.manifest
images/*.svg
shapes/*.shape
```

Each icon is listed with a clean searchable name based on the original SVG filename.

To regenerate the Lucidchart package:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-lucidchart-library.ps1
```
