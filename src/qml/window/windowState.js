.pragma library
var targetMode = undefined

function setTargetMode(m) {
    targetMode = m
}

function takeTargetMode() {
    var m = targetMode
    targetMode = undefined
    return m
}
