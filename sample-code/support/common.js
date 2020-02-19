function appendToContent(nodeType, text) {
  let elem = document.createElement(nodeType);
  elem.append(text);
  document.getElementById('content').append(elem);
}
