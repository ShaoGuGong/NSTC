#import "@preview/numblex:0.2.0": numblex
#import "@preview/cuti:0.3.0": show-cn-fakebold

#let conf(
  doc,
) = {
  // ───────────────────────────── Set Content ─────────────────────────────
  set page(
    paper: "a4",
    margin: 2.54cm,
  )
  set columns(gutter: 12pt)
  set par(
      justify: true,
      first-line-indent: (amount: 2em, all: true),
      // leading: 1.0em,
  )
  // set par(justify: true)
  // ─────────────────────────────── Set CJK ───────────────────────────────
  show: show-cn-fakebold
  let han-or-punct = "[-\p{sc=Hani}。．，、：；！‼？⁇⸺——……⋯⋯～–—·・‧/／「」『』“”‘’（）《》〈〉【】〖〗〔〕［］｛｝＿﹏●•]"
  show regex(han-or-punct + " " + han-or-punct): it => {
    let (a, _, b) = it.text.clusters()
    a + b
  }
  set text(
      font: (
          (name: "Times New Roman", covers: "latin-in-cjk"),
          "TW-MOE-Std-Kai",
          "思源宋體 TW",
      ),
    size: 12pt,
    lang: "zh",
    region: "TW",
  )

  // ────────────────────────────── Set List ───────────────────────────
  set list(indent: 2em)
  set enum(numbering: "1.a.", indent: 2em)

  // ───────────────────────── Set Math Equations ──────────────────────
  set math.equation(number-align: right + horizon, numbering: "(1)")
  show math.equation: set block(spacing: 0.65em)

  // ───────────────────────────── Set Figure ──────────────────────────
  set figure.caption(separator: "、")
  set figure(numbering: "一")
  show figure.where(
    kind: table,
  ): set figure.caption(position: top)
  show figure: set par(justify: false)
  show figure.where(
      kind: "algorithm",
  ): set figure(numbering: "1", supplement: [Algorithm])

  // ─────────────────────────── Set Code Blocks ───────────────────────────
  show raw: set text(font: "Victor Mono", size: 8pt)

  //Set ref
    show ref: it => {
      let eq = math.equation
      let el = it.element
      if el != none and el.func() == eq {
        // Override equation references.
        numbering(
          el.numbering,
          ..counter(eq).at(el.location())
        )
      } else {
        // Other references as usual.
        it
      }
    }

  // ───────────────────────────── Set Heading ─────────────────────────────
  set heading(numbering: numblex("{第[一]章:d==1}{第[一]節:d==2}{第[一]小節:d==3}"))
  show heading: it => {
    if it.level == 1 [
        #let is-ack = it.body in (
            [Acknowledgment], [Acknowledgement], [參考文獻],
        )
      #set align(center)
      #set text(size: 14pt, weight: "bold")
      #v(1.5em, weak: true)
      #if it.numbering != none and not is-ack {
        counter(heading).display()
        h(0.5em, weak: true)
      }
      #it.body
      #v(1em, weak: true)
    ] else if it.level == 2 [
      #set par(first-line-indent: 0pt)
      #set text(size: 12pt, weight: "regular")
      #v(1em, weak: true)
      #if it.numbering != none {
        counter(heading).display()
        h(0.5em, weak: true)
      }
      #it.body
      #v(1em, weak: true)
    ] else if it.level == 3 [
      #set par(first-line-indent: 0pt)
      #set text(size: 12pt, weight: "regular")
      #v(1em, weak: true)
      #if it.numbering != none {
        counter(heading).display()
        h(0.5em, weak: true)
      }
      #it.body
      #v(1em, weak: true)
    ]
  }
  doc
}
