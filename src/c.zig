pub usingnamespace @cImport({
    // @TODO: support STB config definitions (i.e. STBI_NO_STDIO)
    // through the build script.
    @cInclude("stb_image.h");
});
