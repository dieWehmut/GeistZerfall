// characterImageMap.js - support multiple variants per character and named styles
// Mapping structure supports either:
// 1) An object with keys like "0","1","gray","red" -> paths, or
// 2) An array of paths (variants) where numeric indices select items.
// The helper resolves the requested style (number or string) with fallbacks.
// Numeric style codes supported (for convenience):
// 0 -> default/base, 1 -> gray, 2 -> black, 3 -> red, 4 -> child
// Load concrete mapping from JSON file in the same directory. This keeps data separate from logic.
var characterImageMap = (function() {
    // Try resource URLs first (qrc and :/), then fall back to resolved local path
    var urlCandidates = [":/qml/window/Lore/components/characterImageMap.json"];
    var parsed = null;
    for (var ui = 0; ui < urlCandidates.length; ++ui) {
        var tryUrl = urlCandidates[ui];
        if (!tryUrl) continue;
        try {
            var req = new XMLHttpRequest();
            req.open("GET", tryUrl, false); // synchronous load
            req.send();
            if (req.status === 200 || req.status === 0) {
                parsed = JSON.parse(req.responseText);
                console.log("characterImageMap: loaded", tryUrl);
                break;
            } else {
                console.log("characterImageMap: failed to load, status", req.status, "url", tryUrl);
            }
        } catch (e) {
            console.log("characterImageMap: exception while loading", e, "url", tryUrl);
        }
    }
    if (parsed) {
        // Support both new { map: {...}, aliases: {...}, numericStyleMap: {...} }
        // and legacy flat map (where parsed is the map itself).
        var rawMap = parsed.map ? parsed.map : parsed;
        // attach helpers back onto returned object
        rawMap.__meta__ = {
            aliases: parsed.aliases || {},
            numericStyleMap: parsed.numericStyleMap || null
        };
        return rawMap;
    }
    // fallback: empty map
    return {};
})();

// create aliases for transliterated keys -> point to the same object
// Apply aliases from JSON metadata (keeps alias definitions out of JS).
try {
    var aliases = (characterImageMap.__meta__ && characterImageMap.__meta__.aliases) ? characterImageMap.__meta__.aliases : {};
    for (var a in aliases) {
        if (!aliases.hasOwnProperty(a)) continue;
        try {
            if (characterImageMap[a]) continue; // don't overwrite
            var target = aliases[a];
            // support nested target like "医生.male"
            var parts = target.split(".");
            var ref = characterImageMap;
            var ok = true;
            for (var pi = 0; pi < parts.length; ++pi) {
                if (ref[parts[pi]] === undefined) { ok = false; break; }
                ref = ref[parts[pi]];
            }
            if (ok) characterImageMap[a] = ref;
        } catch(e) { /* ignore per-entry errors */ }
    }
} catch(e) { /* ignore overall errors */ }

function findCharacterEntry(name) {
    if (!name) return null;
    if (characterImageMap[name]) return characterImageMap[name];
    return null;
}

// resolveStyleKey: accepts number or string to canonical style key (string)
function resolveStyleKey(style) {
    if (style === undefined || style === null) return null;
    if (typeof style === 'number') return String(style);
    if (typeof style === 'string') {
        return style; // keep as-is e.g. 'gray' or '0'
    }
    return null;
}

// numeric style mapping: numeric codes map to named style keys
// numeric style mapping: can be overridden from JSON via characterImageMap.__meta__.numericStyleMap
var NUMERIC_STYLE_MAP = (characterImageMap.__meta__ && characterImageMap.__meta__.numericStyleMap) ? characterImageMap.__meta__.numericStyleMap : {
    '0': '0',
    '1': 'gray',
    '2': 'black',
    '3': 'red',
    '4': 'child'
};

// getCharacterImageFor: accepts either an object with { name, style, image }
// or just a string name (deprecated). Style can be numeric or string.
function getCharacterImageFor(charData) {
    if (!charData) return "";
    // If explicitly provided an image path, use it
    if (typeof charData === 'string') {
        // name-only; return default variant
        var e = findCharacterEntry(charData);
        if (!e) return "";
        // if nested by gender -> default to male
        if (e['male'] || e['female']) {
            var genderDefault = 'male';
            var gEntry = e[genderDefault] || e['female'];
            if (gEntry && gEntry['0']) return gEntry['0'];
            if (gEntry && gEntry['black']) return gEntry['black'];
            if (gEntry && gEntry['gray']) return gEntry['gray'];
        }
        // default: try key '0' or first available key
        if (e['0']) return e['0'];
        for (var k in e) if (e.hasOwnProperty(k)) return e[k];
        return "";
    }
    if (charData.image) return charData.image;
    var name = charData.name;
    var styleKey = resolveStyleKey(charData.style);
    var entry = findCharacterEntry(name);
    if (!entry) return "";
    // if entry is gender-nested object, select based on charData.gender (defaults to male)
    if (entry['male'] || entry['female']) {
        var g = 'male';
        if (charData.gender) {
            var gstr = (typeof charData.gender === 'string') ? charData.gender.toLowerCase() : '';
            if (gstr === 'female' || gstr === 'f' || gstr === '女' || gstr === 'female') g = 'female';
            else if (gstr === 'male' || gstr === 'm' || gstr === '男') g = 'male';
        }
        if (entry[g]) entry = entry[g];
        else entry = entry['male'] || entry['female'];
    }
    // If requested a specific style key
    if (styleKey) {
        // numeric index style as string '0'
        if (entry[styleKey]) return entry[styleKey];
        // map numeric string like '1','2' to known named style keys
        if (!isNaN(Number(styleKey))) {
            var mapped = NUMERIC_STYLE_MAP[styleKey];
            if (mapped && entry[mapped]) return entry[mapped];
        }
        // if styleKey is a numeric string but entry might be array stored as 'variants'
        if (Array.isArray(entry)) {
            var idx = Number(styleKey);
            if (!isNaN(idx) && entry.length > idx) return entry[idx];
        }
    }
    // If no styleKey or requested style not present: fallback rules
    // 1) If entry has '0' use it
    if (entry['0']) return entry['0'];
    // 1b) if entry has 'black' prefer that in absence of '0'
    if (entry['black']) return entry['black'];
    // 1c) legacy: if entry has 'gray' prefer that
    if (entry['gray']) return entry['gray'];
    // 2) If entry is an array -> return first
    if (Array.isArray(entry) && entry.length > 0) return entry[0];
    // 3) otherwise return first available property value
    for (var kk in entry) {
        if (entry.hasOwnProperty(kk)) return entry[kk];
    }
    return "";
}

// Helper: list variants for a character name (can help debugging/testing)
function listCharacterVariants(name) {
    var e = findCharacterEntry(name);
    if (!e) return [];
    if (Array.isArray(e)) return e;
    var out = [];
    // If the entry is gender-nested, expand with gender prefix
    if (e['male'] || e['female']) {
        var genders = ['male','female'];
        for (var gi = 0; gi < genders.length; ++gi) {
            var g = genders[gi];
            if (!e[g]) continue;
            var sub = e[g];
            for (var kk in sub) if (sub.hasOwnProperty(kk)) out.push({ key: g + '_' + kk, path: sub[kk] });
        }
        return out;
    }
    for (var k in e) if (e.hasOwnProperty(k)) out.push({ key: k, path: e[k] });
    return out;
}

// Exported helper names used by QML files: findCharacterImageFromName (legacy), getCharacterImageFor
function findCharacterImageFromName(name) { return getCharacterImageFor(name); }
