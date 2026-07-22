# Was passiert bei `slothy.optimize()`?

Grob gibt es **sechs Phasen**: Textvorbereitung → Parsen in Instruktionsobjekte → Aufbau des Datenflussgraphen → Aufstellen und Lösen eines Constraint-Modells (ILP/CP-SAT) → Ergebnis auslesen (Reordering + Register-Renaming) → Zurückschreiben als Assembly-Text.

Der Kern der Frage — **Parsen → Instruktionsobjekt → Zurückschreiben** — steckt in den Phasen 2, 5 und 6. Als durchgängiges Beispiel dient die Zeile `add x5, x6, x7`.

---

## Phase 1 — Textvorbereitung (`slothy/core/slothy.py`)

`Slothy.optimize(start, end, ...)` ist der Einstieg. Es schneidet den zu optimierenden Bereich heraus und bereitet den Text zeilenweise auf, *bevor* irgendetwas geparst wird.

- **`optimize()`** (`slothy.py:327`) — Orchestriert den ganzen Ablauf: Region extrahieren, Preprocessing, dann `Heuristics.periodic(...)` aufrufen und das Ergebnis wieder in `self.source` einsetzen.
- **`AsmHelper.extract(source, start, end)`** — Teilt den Quelltext in `pre` / `body` / `post` anhand der Label `start`/`end`; nur `body` wird optimiert.
- **`AsmAllocation.parse_allocs(pre)`** — Liest Register-Alias-Definitionen (z.B. `.req`) aus dem Vorspann ein.
- **`config.copy()` + `c.add_aliases(...)`** — Erstellt eine lokale Kopie der Konfiguration und registriert die gefundenen Aliase.
- **`AsmHelper.find_indentation(body)`** — Ermittelt die dominante Einrückung, um sie später beim Zurückschreiben zu reproduzieren.
- **`CPreprocessor.unfold(...)`** — Optional: lässt den C-Präprozessor über den Code laufen (Makros aus `#define` etc.).
- **`SourceLine.split_semicolons(body)`** — Zerlegt mehrere per `;` getrennte Instruktionen in eine Zeile pro Instruktion.
- **`unfold_all_directives(...)`** — Expandiert Assembler-Makros/Direktiven zu einzelnen Instruktionen.
- **`AsmAllocation.unfold_all_aliases(...)`** — Ersetzt Register-Aliase durch die echten Registernamen (z.B. `a0` → `x10`).
- **`AsmIfElse.process_instructions(body)`** — Behandelt bedingte `.if/.else`-Assembler-Konstrukte.
- **`SourceLine.apply_indentation(...)`** — Normalisiert die Einrückung.

Nach Phase 1 ist `body` eine Liste von `SourceLine`-Objekten, jede mit genau einer Instruktion als reinem Text — z.B. `"add x5, x6, x7"`.

---

## Phase 2 — Parsen in Instruktionsobjekte (der DFG wird gebaut)

`optimize()` ruft **`Heuristics.periodic(body, logger, c)`** (`heuristics.py:337`). Diese Heuristik (bzw. `Heuristics.linear`) baut letztlich einen `DataFlowGraph`, und *dessen Konstruktor* ist es, der jede Zeile parst.

### DFG-Aufbau (`slothy/core/dataflow.py`)

- **`DataFlowGraph.__init__(src, logger, config)`** (`dataflow.py:717`) — Ruft `_parse_source(src)` (Text → Instruktionsobjekte) und danach `_build_graph()` (Objekte → Graph mit Abhängigkeiten) auf.
- **`_parse_source(src)`** (`dataflow.py:794`) — Reduziert/vereinheitlicht die Zeilen (`SourceLine.reduce_source`, `unify_source`) und mappt `_parse_line` über jede Zeile.
- **`_parse_line(line)`** (`dataflow.py:785`) — Ruft **`self.arch.Instruction.parser(line)`** auf, also den architekturspezifischen Parser, und merkt sich `inst.source_line` (die Original-Zeile mit Kommentaren/Tags).

### Der eigentliche Parser (`riscv/instruction_core.py`)

- **`Instruction.parser(src_line)`** (`instruction_core.py:281`) — Zentrale Fabrik: iteriert über **alle** Instruktionsklassen (`all_subclass_leaves`) und probiert für jede `inst_class.make(src)`, bis eine ohne `ParsingException` durchkommt. Setzt danach `source_line`, markiert Branches als solche und ruft `extract_read_writes()` auf.
- **`all_subclass_leaves(Instruction)`** (`instruction_core.py:329`) — Sammelt rekursiv alle Blatt-Klassen des Instruktions-Klassenbaums (also die konkreten Instruktionen wie `add`, `addi`, `lw` …).

Für unser `add x5, x6, x7` matcht die Klasse `add` (dynamisch erzeugt aus `RISCVIntegerRegisterRegister`, siehe unten):

- **`make(cls, src)`** (`riscv_instruction_core.py:333`) — Dünner Wrapper, ruft `RISCVInstruction.build(cls, src)`.
- **`RISCVInstruction.build(c, src)`** (`riscv_instruction_core.py:285`) — Holt das `pattern` der Klasse (`"add <Xd>, <Xa>, <Xb>"`), ersetzt Platzhalter wie `<w>`, `<len>`, `<vm>`, prüft grob den Mnemonic, baut per `get_parser(pattern)(src)` das Regex-Match-Dict und instanziiert dann das Objekt `c(...)` und füllt es via `build_core`.
- **`get_parser(pattern)`** (`riscv_instruction_core.py:147`) — Cached für jedes Pattern einen kompilierten Regex-Parser (`PARSERS`-Dict), damit dasselbe Pattern nicht mehrfach übersetzt wird.
- **`_build_parser(src)` / `_unfold_pattern(src)`** (`riscv_instruction_core.py:122` / `:56`) — Übersetzen das menschenlesbare Pattern `"add <Xd>, <Xa>, <Xb>"` in einen echten Regex mit benannten Gruppen. `<Xd>` etc. werden zu Register-Capture-Gruppen, `<imm>`/`<label>`/`<sew>`… zu passenden Untermustern. (Hier stehen übrigens noch zwei `print(src)`-Debugausgaben drin — dazu unten mehr.)
- **`RISCVInstruction.__init__(pattern, inputs, outputs, in_outs)`** (`riscv_instruction_core.py:167`) — Konstruktor des konkreten Objekts: leitet aus den Pattern-Namen die Registertypen ab (`_infer_register_type`: `x…`→`BASE_INT`, `v…`→`VECT`), setzt `pattern_inputs/outputs/in_outs` und ruft den Basis-`Instruction.__init__`.
- **`_infer_register_type(ptrn)`** (`riscv_instruction_core.py:157`) — Bestimmt anhand des ersten Buchstabens (`X`/`V`) den Registertyp.
- **`RISCVInstruction.build_core(obj, res)`** (`riscv_instruction_core.py:238`) — Füllt das Objekt aus dem Regex-Match-Dict `res`: setzt Attribute wie `immediate`, `index`, `label`, `sew`, `lmul` … via `group_to_attribute`, und schreibt die konkreten Register in `args_in`, `args_out`, `args_in_out` (mit `_to_reg`, das z.B. eine reine Zahl `5` zu `x5` macht).
- **`Instruction.__init__(...)`** (`instruction_core.py:39`) — Basiskonstruktor: legt die Zähler `num_in/num_out/num_in_out`, die leeren `args_*`-Listen und alle Zusatzfelder (`immediate`, `datatype`, `vtype`, …) an.
- **`extract_read_writes()`** (`instruction_core.py:95`) — Liest `// reads:`/`// writes:`-Tags aus dem Kommentar der Zeile und hängt für Speicherzugriffe künstliche „Hint"-Register an die Ein-/Ausgaben an (Modellierung von Memory-Dependencies).

**Ergebnis:** Aus dem String `"add x5, x6, x7"` ist jetzt ein `add`-Objekt geworden mit
`args_out = ["x5"]`, `args_in = ["x6", "x7"]`, `arg_types_* = [BASE_INT, …]`, `pattern = "add <Xd>, <Xa>, <Xb>"`.

### Woher kommt die Klasse `add`? (`riscv/rv32_64_i_instructions.py` + `riscv_super_instructions.py`)

Die konkreten Instruktionsklassen werden nicht von Hand geschrieben, sondern **dynamisch generiert**:

- **`generate_rv32_64_i_instructions()`** (`rv32_64_i_instructions.py:75`) — Läuft beim Import einmal durch und ruft für jede Instruktionsgruppe `instr_factory`.
- **`instr_factory(instr_list, baseclass)`** (`riscv_instruction_core.py:385`) — Erzeugt per `type(...)` für jeden Mnemonic (`add`, `sub`, `xor`, …) eine neue Klasse, die von einer Basisklasse erbt und deren `pattern` mit dem konkreten Mnemonic füllt. `add` erbt so von **`RISCVIntegerRegisterRegister`** mit `pattern = "add <Xd>, <Xa>, <Xb>"`, `inputs=["Xa","Xb"]`, `outputs=["Xd"]`.

### Graph-Aufbau aus den Objekten

- **`_build_graph()`** (`dataflow.py:948`) — Fügt jede Instruktion nacheinander via `_add_node_from_candidates` in den Graphen ein und ergänzt am Ende virtuelle Output-Knoten für die deklarierten globalen Outputs.
- **`_add_node_from_candidates(candidates, sourceline)`** (`dataflow.py:973`) — Filtert die Kandidaten-Parsings per `_typecheck_node` und stellt sicher, dass **genau eine** Interpretation typkorrekt ist (sonst Fehler wegen Mehrdeutigkeit).
- **`_typecheck_node(s)`** (`dataflow.py:815`) — Prüft, ob die abgeleiteten Registertypen zu dem passen, was das Modell/das bisherige „Typing-Dictionary" erwartet.
- **`_add_node(s)`** (`dataflow.py:1035`) — Baut den eigentlichen Graphknoten: sucht für jeden Eingang die Quelle (`_find_source_single`), legt den `ComputationNode` an und trägt die Ausgaben in `reg_state` ein (welche Instruktion zuletzt welches Register schrieb).
- **`_find_source_single(ty, name)`** (`dataflow.py:996`) — Findet den Produzenten eines Eingangsregisters; ist es noch ungeschrieben, wird ein virtueller Input-Knoten (`VirtualInputInstruction`) angelegt → das ist ein globaler Input.
- **`ComputationNode.__init__(...)`** (`dataflow.py:202`) — Repräsentiert eine Instruktion im Graphen; verknüpft sich mit den Produzenten seiner Eingänge (`src_in`/`src_in_out`) und berechnet die Tiefe (längste Abhängigkeitskette).
- **`apply_parsing_cbs()`** (`dataflow.py:637`) — Ruft nach dem Bau pro Knoten `global_parsing_cb` auf, um Instruktionen nachträglich umzumodellieren (z.B. „jointly destructive" Muster, bei denen ein In/Out zu einem reinen Output wird).
- **`_selfcheck_outputs()`** (`dataflow.py:732`) — Warnt/failt, wenn eine Instruktion ein Ergebnis produziert, das weder benutzt noch als globaler Output deklariert ist (typischer Konfigurationsfehler).

---

## Phase 3–5 — Modell aufstellen und lösen (`slothy/core/core.py`)

`Heuristics` ruft schließlich **`SlothyBase.optimize(...)`** (`core.py:1648`). Vereinfacht:

- **`SlothyBase.optimize(source, ...)`** — Baut aus dem DFG ein CP-SAT-Constraint-Modell (Google OR-Tools) und löst es.
- **`_add_variables_scheduling()`** (`core.py:2585`) — Legt für jede Instruktion eine Positions-Variable an (wo im optimierten Code sie landet).
- **`_add_variables_functional_units()`** (`core.py:2642`) — Modelliert die Ausführungseinheiten der Mikroarchitektur (aus dem Target-Modell, z.B. `xuantie_c908`).
- **`_add_variables_dependencies()`** (`core.py:2687`) — Übersetzt die DFG-Kanten in Latenz-/Reihenfolge-Constraints.
- **`_add_variables_register_renaming()`** (`core.py:2729`) — Legt Boolean-Variablen an, die entscheiden, welches physische Register jeder Ein-/Ausgang bekommt (das ist die Register-Allokation).

Der Solver liefert dann für jede Instruktion (a) eine neue **Position** und (b) für jeden Operanden ein gewähltes **Register**.

---

## Phase 6 — Ergebnis auslesen und zurückschreiben

- **`_extract_result()`** (`core.py:2197`) — Liest die Lösung aus dem Solver und baut das `Result`-Objekt.
- **`_extract_positions(get_value)`** (`core.py:2214`) — Liest die Positionsvariablen aus und baut daraus `reordering_with_bubbles` (die Permutation alt→neu).
- **`_extract_register_renamings(get_value)`** (`core.py:2303`) — Für jeden Knoten wird die eine „wahre" Renaming-Variable ausgelesen und **direkt zurück in `t.inst.args_out/args_in/args_in_out` geschrieben**. Hier verändert sich das Instruktionsobjekt: aus `add x5, x6, x7` könnte z.B. `add x9, x6, x7` werden.
- **`_extract_input_output_renaming()`** (`core.py:2288`) — Baut die Tabellen, welche globalen Ein-/Ausgaberegister umbenannt wurden.
- **`_extract_code()`** (`core.py:2401`) — Erzeugt die neue Quelltext-Reihenfolge, indem es die Knoten in ihrer neuen Position durchläuft und jeden per `ComputationNode.to_source_line` in eine `SourceLine` verwandelt.
- **`ComputationNode.to_source_line()`** (`dataflow.py:254`) — Kopiert die Original-`SourceLine` (behält Kommentare/Tags) und ersetzt den Text durch `str(self.inst)` — also die Stringifizierung des (jetzt umbenannten) Instruktionsobjekts.
- **`RISCVInstruction.write()`** (`riscv_instruction_core.py:337`) — Das ist der **Rückweg vom Objekt zum Text**: Es nimmt das ursprüngliche `pattern` und setzt über `_instantiate_pattern` die aktuellen Register aus `args_*` sowie alle Extra-Felder (`immediate`, `label`, `sew`, …) wieder ein. Aus dem Objekt mit `args_out=["x9"], args_in=["x6","x7"]` wird so wieder `"add x9, x6, x7"`.
- **`_instantiate_pattern` / `_build_pattern_replacement` / `_to_reg`** (`riscv_instruction_core.py:230/218/206`) — Helfer, die einen Pattern-Platzhalter wie `<Xd>` durch den konkreten Registernamen ersetzen und dabei Groß-/Kleinschreibung und symbolische Register korrekt behandeln.
- **`selfcheck_with_fixup()` / `_selfcheck_core()`** (`core.py:1000/1056`) — Baut aus dem Ergebnis erneut einen DFG und verifiziert, dass die Umsortierung + Umbenennung **semantisch identisch** zum Original ist (SLOTHY garantiert, dass es keine Instruktion ändert).
- **`offset_fixup()`** (`core.py:1413`) — Korrigiert ggf. Adress-Offsets bei Load/Store nach dem Reordering.

Zurück in **`Slothy.optimize()`** wird das Ergebnis (`core` / bei Software-Pipelining `early`/`late`) wieder mit `pre` und `post` zusammengesetzt und in `self.source` geschrieben — als `SourceLine`-Liste, die man per `get_source_as_string()` als fertiges Assembly ausgeben kann.

---

## Der rote Faden am Beispiel `add x5, x6, x7`

```
"add x5, x6, x7"  (SourceLine, Text)
      │  Instruction.parser → add.make → RISCVInstruction.build → build_core
      ▼
add-Objekt: pattern="add <Xd>,<Xa>,<Xb>", args_out=["x5"], args_in=["x6","x7"]
      │  DataFlowGraph._add_node  (Abhängigkeiten: x6,x7 = Inputs; x5 = Output)
      ▼
ComputationNode im DFG
      │  SlothyBase.optimize → CP-SAT: neue Position + Register-Wahl
      ▼
_extract_register_renamings: args_out=["x9"]   (Renaming z.B. x5→x9)
      │  to_source_line → RISCVInstruction.write()
      ▼
"add x9, x6, x7"  (neue SourceLine, evtl. an anderer Position)
```
