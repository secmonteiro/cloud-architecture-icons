# cloud-architecture-icons

Custom draw.io / diagrams.net library for the cloud architecture SVG icons in this repository.

## Import in draw.io

Use the generated library file at the repository root:

```text
cloud-architecture-icons.xml
```

In draw.io / diagrams.net:

1. Open the editor.
2. Go to `File > Open Library From > GitHub`.
3. Select this repository and open `cloud-architecture-icons.xml`.

The library embeds every SVG icon as a base64 SVG data URI, so draw.io imports the complete icon set from this single XML file.

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
