.pragma library
var targetMode = undefined
var loreState = undefined
var gameEnemies = undefined

function setTargetMode(m) {
    targetMode = m
}

function takeTargetMode() {
    var m = targetMode
    targetMode = undefined
    return m
}

// Lore view state persistence
// obj: { chapter: string, node: string, index: int, mode: string, auto: bool }
function setLoreState(obj) {
    loreState = obj
}

function getLoreState() {
    return loreState
}

function clearLoreState() {
    loreState = undefined
}

// Game enemy snapshot persistence (used between navigation when window.currentEnemyList property not available)
function setGameEnemies(list) {
    gameEnemies = list
}

function getGameEnemies() {
    return gameEnemies
}

function clearGameEnemies() {
    gameEnemies = undefined
}
