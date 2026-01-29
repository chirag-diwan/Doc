function tokenize(input) {
  const tokens = []
  const regex = /\s*(let|print|\d+|[a-zA-Z_]\w*|==|=|\+|\-|\*|\/|\(|\))\s*/g
  let match

  while ((match = regex.exec(input)) !== null) {
    tokens.push(match[1])
  }

  return tokens
}




function parse(tokens) {
  let pos = 0

  function peek() {
    return tokens[pos]
  }

  function consume(expected) {
    const token = tokens[pos]
    if (expected && token !== expected) {
      throw new Error(`Expected '${expected}', got '${token}'`)
    }
    pos++
    return token
  }

  function parseExpression() {
    let node = parseTerm()

    while (peek() === "+" || peek() === "-") {
      const op = consume()
      const right = parseTerm()
      node = { type: "Binary", op, left: node, right }
    }

    return node
  }

  function parseTerm() {
    let node = parseFactor()

    while (peek() === "*" || peek() === "/") {
      const op = consume()
      const right = parseFactor()
      node = { type: "Binary", op, left: node, right }
    }

    return node
  }

  function parseFactor() {
    const token = peek()

    if (/^\d+$/.test(token)) {
      consume()
      return { type: "Number", value: Number(token) }
    }

    if (/^[a-zA-Z_]\w*$/.test(token)) {
      consume()
      return { type: "Variable", name: token }
    }

    if (token === "(") {
      consume("(")
      const expr = parseExpression()
      consume(")")
      return expr
    }

    throw new Error("Unexpected token: " + token)
  }
}
