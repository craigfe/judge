(import ./util)

# 1-indexed -> 0-indexed
(defn- normalize-pos [[line col]]
  [(- line 1) (- col 1)])

(defn- delimited? [x]
  (case (type x)
    :array true
    :tuple true
    :table true
    :struct true
    :string true
    :buffer true
    false))

(defn- pos-to-byte-index [lines pos]
  (var bytes 0)
  (def [target-line target-col] (normalize-pos pos))
  (for i 0 target-line (+= bytes (length (in lines i))))
  # add target-line to account for the newlines.
  # not really sure how \r\n newlines would work.
  #(def line-contents (in lines (- target-line 1)))
  #(+ bytes target-line (min (length line-contents) target-col)))
  (+ bytes target-line target-col))

(defn- get-form-length [source start-index]
  (def p (parser/new))

  (var form-length 0)

  (while (not (parser/has-more p))
    (when (= (parser/status p) :error)
      (error "parse error while trying to find the end of a form"))
    (when (> (+ start-index form-length) (length source))
      (error "reached end-of-string before finding the end of the form"))
    (parser/byte p (in source (+ start-index form-length)))
    (++ form-length))

  # we found a value, which means that either
  # we parsed a closing delimiter, or a character
  # that cannot be part of an atom. So we will have
  # advanced something like this:
  # "(hello)"
  # "hello "
  # "hello)"
  (if (delimited? (parser/produce p))
    form-length
    (- form-length 1)))

# replacements is a list of [start-index length new-string]
(defn- string-splice [str replacements]
  (def replacements (sorted-by 0 replacements))

  (do
    (var invalid-to 0)
    (each [start len _] replacements
      (when (> invalid-to start)
        (error "overlapping replacements"))
      (set invalid-to (+ start len))))

  (def components @[])
  (var cursor 0)
  (each [start len replacement] replacements
    (array/push components (string/slice str cursor start))
    (array/push components replacement)
    (set cursor (+ start len)))
  (array/push components (string/slice str cursor))

  (string/join components))

(defn- char-at [x i]
  (string/from-bytes (x i)))

(defn- whitespace? [x]
  (or (= x " ") (= x "\t") (= x "\n")))

# returns an array of byte indices for the start of each
# subform, in the coordinate space of the source input
(defn components [source start-index form-length]
  (assert (>= form-length 2) "but where are the parentheses??")
  (def innards (util/slice-len source (+ start-index 1) (- form-length 2)))
  (def lines (string/split "\n" innards))
  (def p (parser/new))
  (parser/consume p innards)
  (parser/eof p)
  (def result @[])
  (while (parser/has-more p)
    (array/push result
      (+ start-index 1
        (pos-to-byte-index lines
          (tuple/sourcemap (parser/produce p true))))))
  result)

(defn get-form [{:source source :lines lines} pos]
  (def start (pos-to-byte-index lines pos))
  (def len (get-form-length source start))
  (util/slice-len source start len))

# replacements should be a list of [form-pos replacement-str]
(defn rewrite-forms [{:source source :lines lines} replacements]
  (string-splice source (seq [[pos replacement] :in replacements]
    (def start (pos-to-byte-index lines pos))
    (def len (get-form-length source start))

    (def components (components source start len))
    (def third-form-end (+ start len -1))
    (def third-form-start
      (case (length components)
        0 (error "cannot patch")
        1 (errorf "cannot patch")
        2 third-form-end
        (in components 2)))

    (def third-form-len (- third-form-end third-form-start))

    [third-form-start
     third-form-len
     (if (whitespace? (char-at source (- third-form-start 1)))
      replacement
      (string " " replacement))])))

(defn rewrite-form [source pos replacement]
  (rewrite-forms {:source source :lines (string/split "\n" source)} [[pos replacement]]))

(defn pos-in-form? [{:source source :lines lines} form-pos target-pos]
  (def form-start-index (pos-to-byte-index lines form-pos))
  (def form-length (get-form-length source form-start-index))
  (def target-start-index (pos-to-byte-index lines target-pos))

  (and (>= target-start-index form-start-index)
       (< target-start-index (+ form-start-index form-length))))
