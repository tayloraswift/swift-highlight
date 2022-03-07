<div align="center">
  
***`highlight`***<br>`0.1.0`

</div>

`swift-highlight` is a pure-Swift data structure library designed for server applications that need to store a lot of styled text. The `Highlight` module is memory-efficient and uses slab allocations and small-string optimizations to pack large amounts of styled text into a small amount of memory, while still supporting efficient traversal through the [`Sequence`](https://swiftinit.org/reference/swift/sequence) protocol.

**Importing this module will expose the following top-level symbol(s)**:

* `struct NotebookStorage`

* `struct NotebookContent<Highlight>`

* `struct Notebook<Highlight, Link>`
