#import "mod/mod.typ": conf

#show: conf.with()
#set page(numbering: "I")

#outline(depth: 2, target: heading)

#pagebreak()
#heading(numbering: none, level: 1)[圖目錄]
#outline(title: [], target: figure.where(kind: image))

#pagebreak()
#heading(numbering: none, level: 1)[表目錄]
#outline(title: [], target: figure.where(kind: table))

#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)

#include "chapter/intro.typ"

#include "chapter/related-work.typ"

#include "chapter/method.typ"

#include "chapter/experiments.typ"

#include "chapter/results.typ"

#pagebreak()
#heading(numbering: none, level: 1)[參考文獻]
#set text(lang: "us")
#bibliography("citations/NSTC_repo.bib", title: none)

// Local Variables:
// tp--master-file: "/home/shaogu/Documents/NSTC/repo/main.typ"
// End:
