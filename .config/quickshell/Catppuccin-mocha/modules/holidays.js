.pragma library
// Feriados nacionais do Brasil (fixos + móveis baseados na Páscoa)

// Domingo de Páscoa (algoritmo gregoriano anônimo / Meeus)
function easter(year) {
    var a = year % 19, b = Math.floor(year / 100), c = year % 100
    var d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25)
    var g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30
    var i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
    var m = Math.floor((a + 11 * h + 22 * l) / 451)
    var month = Math.floor((h + l - 7 * m + 114) / 31) - 1
    var day = ((h + l - 7 * m + 114) % 31) + 1
    return new Date(year, month, day)
}

function addDays(date, n) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n)
}

function key(date) {
    return date.getFullYear() + "-" + date.getMonth() + "-" + date.getDate()
}

var cache = {}

// { "aaaa-m-d": { name, optional } } para o ano dado
function forYear(year) {
    if (cache[year]) return cache[year]
    var map = {}
    function add(date, name, optional) { map[key(date)] = { name: name, optional: !!optional, date: date } }
    var e = easter(year)
    add(new Date(year, 0, 1), "Confraternização Universal")
    add(addDays(e, -48), "Carnaval", true)
    add(addDays(e, -47), "Carnaval", true)
    add(addDays(e, -2), "Sexta-feira Santa")
    add(new Date(year, 3, 21), "Tiradentes")
    add(new Date(year, 4, 1), "Dia do Trabalho")
    add(addDays(e, 60), "Corpus Christi", true)
    add(new Date(year, 8, 7), "Independência do Brasil")
    add(new Date(year, 9, 12), "Nossa Senhora Aparecida")
    add(new Date(year, 10, 2), "Finados")
    add(new Date(year, 10, 15), "Proclamação da República")
    add(new Date(year, 10, 20), "Dia da Consciência Negra")
    add(new Date(year, 11, 25), "Natal")
    cache[year] = map
    return map
}

// feriado na data, ou null
function holidayOn(date) {
    return forYear(date.getFullYear())[key(date)] || null
}

// próximos `count` feriados a partir de hoje (inclusive): [{ name, optional, date, daysUntil }]
function upcoming(from, count) {
    var today = new Date(from.getFullYear(), from.getMonth(), from.getDate())
    var list = []
    for (var y = today.getFullYear(); y <= today.getFullYear() + 1; y++) {
        var map = forYear(y)
        for (var k in map) if (map[k].date >= today) list.push(map[k])
    }
    list.sort(function (a, b) { return a.date - b.date })
    return list.slice(0, count).map(function (h) {
        return { name: h.name, optional: h.optional, date: h.date, daysUntil: Math.round((h.date - today) / 86400000) }
    })
}

// semana ISO 8601
function isoWeek(date) {
    var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    var day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
}

function dayOfYear(date) {
    return Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - new Date(date.getFullYear(), 0, 1)) / 86400000) + 1
}

function daysInYear(year) {
    return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0 ? 366 : 365
}

function relative(days) {
    if (days === 0) return "hoje"
    if (days === 1) return "amanhã"
    return "em " + days + " dias"
}
