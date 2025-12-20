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
    // fallback: embed the JSON directly if loading fails
    console.log("characterImageMap: using embedded fallback map");
    var embeddedMap = {
        "南雲 時": {
            "0": "qrc:/resource/image/characters/NagumoToki.png",
            "black": "qrc:/resource/image/characters/NagumoToki_black.png",
            "gray": "qrc:/resource/image/characters/NagumoToki_gray.png",
            "red": "qrc:/resource/image/characters/NagumoToki_red.png"
        },
        "南雲 枫": {
            "0": "qrc:/resource/image/characters/NagumoKaede.png",
            "black": "qrc:/resource/image/characters/NagumoKaede_black.png",
            "gray": "qrc:/resource/image/characters/NagumoKaede_gray.png",
            "red": "qrc:/resource/image/characters/NagumoKaede_red.png"
        },
        "東堂 陽葵": {
            "0": "qrc:/resource/image/characters/TodoHimari.png",
            "black": "qrc:/resource/image/characters/TodoHimari_black.png",
            "gray": "qrc:/resource/image/characters/TodoHimari_gray.png",
            "red": "qrc:/resource/image/characters/TodoHimari_red.png",
            "child": "qrc:/resource/image/characters/TodoHimari_Child.png",
            "child_black": "qrc:/resource/image/characters/TodoHimari_Child_black.png",
            "child_gray": "qrc:/resource/image/characters/TodoHimari_Child_gray.png",
            "child_red": "qrc:/resource/image/characters/TodoHimari_Child_red.png"
        },
        "藤田 旦治": {
            "0": "qrc:/resource/image/characters/FujitaTanji_black.png",
            "black": "qrc:/resource/image/characters/FujitaTanji_black.png",
            "red": "qrc:/resource/image/characters/FujitaTanji_red.png"
        },
        "常夏 航": {
            "0": "qrc:/resource/image/characters/TokonatsuWataru_black.png",
            "black": "qrc:/resource/image/characters/TokonatsuWataru_black.png",
            "red": "qrc:/resource/image/characters/TokonatsuWataru_red.png"
        },
        "折原 蓮": {
            "0": "qrc:/resource/image/characters/OriharaRen.png",
            "black": "qrc:/resource/image/characters/OriharaRen_black.png",
            "gray": "qrc:/resource/image/characters/OriharaRen_gray.png",
            "red": "qrc:/resource/image/characters/OriharaRen_red.png"
        },
        "清原 凛": {
            "0": "qrc:/resource/image/characters/KiyoharaRin.png",
            "black": "qrc:/resource/image/characters/KiyoharaRin_black.png",
            "gray": "qrc:/resource/image/characters/KiyoharaRin_gray.png",
            "red": "qrc:/resource/image/characters/KiyoharaRin_red.png",
            "child": "qrc:/resource/image/characters/KiyoharaRin_Child_gray.png",
            "child_gray": "qrc:/resource/image/characters/KiyoharaRin_Child_gray.png",
            "child_red": "qrc:/resource/image/characters/KiyoharaRin_Child_red.png"
        },
        "医生": {
            "male": {
                "0": "qrc:/resource/image/characters/MaleDoctor.png",
                "black": "qrc:/resource/image/characters/MaleDoctor_black.png",
                "gray": "qrc:/resource/image/characters/MaleDoctor_gray.png",
                "red": "qrc:/resource/image/characters/MaleDoctor_red.png"
            },
            "female": {
                "0": "qrc:/resource/image/characters/FemaleDoctor.png",
                "black": "qrc:/resource/image/characters/FemaleDoctor_black.png",
                "gray": "qrc:/resource/image/characters/FemaleDoctor_gray.png",
                "red": "qrc:/resource/image/characters/FemaleDoctor_red.png"
            }
        },
        "NagumoToki": {
            "0": "qrc:/resource/image/characters/NagumoToki.png",
            "black": "qrc:/resource/image/characters/NagumoToki_black.png",
            "gray": "qrc:/resource/image/characters/NagumoToki_gray.png",
            "red": "qrc:/resource/image/characters/NagumoToki_red.png"
        },
        "NagumoKaede": {
            "0": "qrc:/resource/image/characters/NagumoKaede.png",
            "black": "qrc:/resource/image/characters/NagumoKaede_black.png",
            "gray": "qrc:/resource/image/characters/NagumoKaede_gray.png",
            "red": "qrc:/resource/image/characters/NagumoKaede_red.png"
        },
        "TodoHimari": {
            "0": "qrc:/resource/image/characters/TodoHimari.png",
            "black": "qrc:/resource/image/characters/TodoHimari_black.png",
            "gray": "qrc:/resource/image/characters/TodoHimari_gray.png",
            "red": "qrc:/resource/image/characters/TodoHimari_red.png",
            "child": "qrc:/resource/image/characters/TodoHimari_Child.png",
            "child_black": "qrc:/resource/image/characters/TodoHimari_Child_black.png",
            "child_gray": "qrc:/resource/image/characters/TodoHimari_Child_gray.png",
            "child_red": "qrc:/resource/image/characters/TodoHimari_Child_red.png"
        },
        "FujitaTanji": {
            "0": "qrc:/resource/image/characters/FujitaTanji_black.png",
            "black": "qrc:/resource/image/characters/FujitaTanji_black.png",
            "red": "qrc:/resource/image/characters/FujitaTanji_red.png"
        },
        "TokonatsuWataru": {
            "0": "qrc:/resource/image/characters/TokonatsuWataru_black.png",
            "black": "qrc:/resource/image/characters/TokonatsuWataru_black.png",
            "red": "qrc:/resource/image/characters/TokonatsuWataru_red.png"
        },
        "OriharaRen": {
            "0": "qrc:/resource/image/characters/OriharaRen.png",
            "black": "qrc:/resource/image/characters/OriharaRen_black.png",
            "gray": "qrc:/resource/image/characters/OriharaRen_gray.png",
            "red": "qrc:/resource/image/characters/OriharaRen_red.png"
        },
        "KiyoharaRin": {
            "0": "qrc:/resource/image/characters/KiyoharaRin.png",
            "black": "qrc:/resource/image/characters/KiyoharaRin_black.png",
            "gray": "qrc:/resource/image/characters/KiyoharaRin_gray.png",
            "red": "qrc:/resource/image/characters/KiyoharaRin_red.png",
            "child": "qrc:/resource/image/characters/KiyoharaRin_Child_gray.png",
            "child_gray": "qrc:/resource/image/characters/KiyoharaRin_Child_gray.png",
            "child_red": "qrc:/resource/image/characters/KiyoharaRin_Child_red.png"
        },
        "Doctor": {
            "male": {
                "0": "qrc:/resource/image/characters/MaleDoctor.png",
                "black": "qrc:/resource/image/characters/MaleDoctor_black.png",
                "gray": "qrc:/resource/image/characters/MaleDoctor_gray.png",
                "red": "qrc:/resource/image/characters/MaleDoctor_red.png"
            },
            "female": {
                "0": "qrc:/resource/image/characters/FemaleDoctor.png",
                "black": "qrc:/resource/image/characters/FemaleDoctor_black.png",
                "gray": "qrc:/resource/image/characters/FemaleDoctor_gray.png",
                "red": "qrc:/resource/image/characters/FemaleDoctor_red.png"
            }
        },
        "医生(男)": {
            "0": "qrc:/resource/image/characters/MaleDoctor.png",
            "black": "qrc:/resource/image/characters/MaleDoctor_black.png",
            "gray": "qrc:/resource/image/characters/MaleDoctor_gray.png",
            "red": "qrc:/resource/image/characters/MaleDoctor_red.png"
        },
        "医生(女)": {
            "0": "qrc:/resource/image/characters/FemaleDoctor.png",
            "black": "qrc:/resource/image/characters/FemaleDoctor_black.png",
            "gray": "qrc:/resource/image/characters/FemaleDoctor_gray.png",
            "red": "qrc:/resource/image/characters/FemaleDoctor_red.png"
        }
    };
    embeddedMap.__meta__ = {
        aliases: {
            "NagumoToki": "南雲 時",
            "NagumoKaede": "南雲 枫",
            "TodoHimari": "東堂 陽葵",
            "FujitaTanji": "藤田 旦治",
            "TokonatsuWataru": "常夏 航",
            "OriharaRen": "折原 蓮",
            "KiyoharaRin": "清原 凛",
            "Doctor": "医生",
            "医生(男)": "医生.male",
            "医生(女)": "医生.female"
        },
        numericStyleMap: {
            "0": "0",
            "1": "gray",
            "2": "black",
            "3": "red",
            "4": "child"
        }
    };
    return embeddedMap;
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
    try {
        if (!charData) { console.log("getCharacterImageFor: charData is falsy", charData); return ""; }
        if (typeof charData === 'string') {
            var e = findCharacterEntry(charData);
            if (!e) { console.log("getCharacterImageFor: entry not found for string", charData); return ""; }
            if (e['male'] || e['female']) {
                var genderDefault = 'male';
                var gEntry = e[genderDefault] || e['female'];
                if (gEntry && gEntry['0']) return gEntry['0'];
                if (gEntry && gEntry['black']) return gEntry['black'];
                if (gEntry && gEntry['gray']) return gEntry['gray'];
            }
            if (e['0']) return e['0'];
            for (var k in e) if (e.hasOwnProperty(k)) return e[k];
            return "";
        }
        if (typeof charData !== 'object' || charData === null) {
            console.log("getCharacterImageFor: charData is not object", charData); return "";
        }
        if (charData.image) try { return charData.image; } catch(e) { console.log("getCharacterImageFor: error accessing image", e, charData); }
        try {
            if (charData.portrait) {
                var p = charData.portrait;
                if (typeof p === 'string') {
                    if (p.indexOf('qrc:') === 0 || p.indexOf(':/') === 0 || p.indexOf('http') === 0) return p;
                    if (p.indexOf('/') === -1) return 'qrc:/resource/image/characters/' + p;
                    return 'qrc:/' + p.replace(/^\/+/, '');
                }
            }
        } catch(e) { console.log("getCharacterImageFor: error accessing portrait", e, charData); }
        var name = (charData.name !== undefined && charData.name !== null) ? String(charData.name) : null;
        var styleKey = resolveStyleKey(charData.style);
        console.log("getCharacterImageFor: name=", name, ", styleKey=", styleKey, ", gender=", charData.gender);
        var entry = findCharacterEntry(name);
        if (!entry) { console.log("getCharacterImageFor: entry not found for name", name); return ""; }
        if (entry['male'] || entry['female']) {
            var g = 'male';
            try {
                if (charData.gender) {
                    var gstr = (typeof charData.gender === 'string') ? charData.gender.toLowerCase() : '';
                    if (gstr === 'female' || gstr === 'f' || gstr === '女') g = 'female';
                    else if (gstr === 'male' || gstr === 'm' || gstr === '男') g = 'male';
                }
            } catch(e) { console.log("getCharacterImageFor: error parsing gender", e, charData); }
            if (entry[g]) {
                entry = entry[g];
                console.log("getCharacterImageFor: gender entry selected", g, entry);
            } else {
                entry = entry['male'] || entry['female'];
                console.log("getCharacterImageFor: fallback gender entry", entry);
            }
        }
        if (!entry) { console.log("getCharacterImageFor: entry is undefined after gender select", name, charData); return ""; }
        if (styleKey) {
            if (entry[styleKey]) { console.log("getCharacterImageFor: found styleKey", styleKey, entry[styleKey]); return entry[styleKey]; }
            if (!isNaN(Number(styleKey))) {
                var mapped = NUMERIC_STYLE_MAP[styleKey];
                if (mapped && entry[mapped]) { console.log("getCharacterImageFor: mapped numeric styleKey", styleKey, "->", mapped, entry[mapped]); return entry[mapped]; }
            }
            if (Array.isArray(entry)) {
                var idx = Number(styleKey);
                if (!isNaN(idx) && entry.length > idx) { console.log("getCharacterImageFor: array styleKey", styleKey, entry[idx]); return entry[idx]; }
            }
            if (typeof styleKey === 'string' && styleKey.indexOf('.') !== -1) {
                var f = styleKey;
                if (f.indexOf('qrc:') === 0 || f.indexOf(':/') === 0 || f.indexOf('http') === 0) { console.log("getCharacterImageFor: styleKey is url", f); return f; }
                if (f.indexOf('/') === -1) { console.log("getCharacterImageFor: styleKey is filename", f); return 'qrc:/resource/image/characters/' + f; }
                console.log("getCharacterImageFor: styleKey is path", f); return 'qrc:/' + f.replace(/^\/+/, '');
            }
        }
        if (entry['0']) { console.log("getCharacterImageFor: fallback '0'", entry['0']); return entry['0']; }
        if (entry['black']) { console.log("getCharacterImageFor: fallback 'black'", entry['black']); return entry['black']; }
        if (entry['gray']) { console.log("getCharacterImageFor: fallback 'gray'", entry['gray']); return entry['gray']; }
        if (Array.isArray(entry) && entry.length > 0) { console.log("getCharacterImageFor: fallback array[0]", entry[0]); return entry[0]; }
        for (var kk in entry) {
            if (entry.hasOwnProperty(kk)) { console.log("getCharacterImageFor: fallback first key", kk, entry[kk]); return entry[kk]; }
        }
        console.log("getCharacterImageFor: no image found for", charData);
        return "";
    } catch(e) {
        try { console.log("characterImageMap: getCharacterImageFor error", e, "charData:", (typeof charData), charData); } catch(_) { console.log("characterImageMap: getCharacterImageFor error (cannot stringify charData)", e); }
        return "";
    }
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
