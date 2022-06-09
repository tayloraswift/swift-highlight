#if swift(>=5.5)
extension NotebookStorage:Sendable {}
extension NotebookContent:Sendable where Color:Sendable {}
extension Notebook:Sendable where Color:Sendable, Link:Sendable {}
#endif 

@frozen public 
struct NotebookStorage:Equatable
{
    public 
    var utf8:[UInt8]
    
    @inlinable public 
    init(utf8:[UInt8])
    {
        self.utf8 = utf8
    }
    
    @inlinable public
    func load<Color>(element:UInt64, at index:inout Int) -> (text:String, color:Color)
        where Color:RawRepresentable, Color.RawValue == UInt8
    {
        withUnsafeBytes(of: element)
        {
            let flags:UInt8 = $0[$0.endIndex - 1]
            guard let color:Color = .init(rawValue: flags & 0b0111_1111)
            else 
            {
                fatalError("could not round-trip raw value '\(flags & 0b0111_1111)'")
            }
            if  flags & 0b1000_0000 != 0 
            {
                // inline UTF-8
                return (String.init(decoding: $0.dropLast().prefix { $0 != 0 }, as: Unicode.UTF8.self), color)
            }
            else 
            {
                // indirectly-allocated UTF-8
                let next:Int = Int.init($0.load(as: UInt32.self))
                let utf8:ArraySlice<UInt8> = self.utf8[index ..< next]
                index = next 
                return (String.init(decoding: utf8, as: Unicode.UTF8.self), color)
            }
        }
    }
    @inlinable public mutating 
    func store<Color>(text:String, color:Color) -> UInt64
        where Color:RawRepresentable, Color.RawValue == UInt8
    {
        var text:String = text
        return text.withUTF8 
        {
            (utf8:UnsafeBufferPointer<UInt8>) in 
            var element:UInt64 = 0 
            withUnsafeMutableBytes(of: &element)
            {
                if utf8.count < $0.count 
                {
                    $0.copyBytes(from: utf8)
                    $0[$0.endIndex - 1] = 0x80 | color.rawValue 
                }
                else 
                {
                    self.utf8.append(contentsOf: utf8)
                    $0.storeBytes(of: UInt32.init(self.utf8.endIndex), as: UInt32.self)
                    $0[$0.endIndex - 1] =        color.rawValue 
                }
            }
            return element
        }
    }
}
@frozen public 
struct NotebookContent<Color>:Sequence, Equatable 
    where Color:RawRepresentable, Color.RawValue == UInt8
{
    public 
    var storage:NotebookStorage
    public 
    var elements:[UInt64]
    
    @inlinable public 
    init()
    {
        self.storage    = .init(utf8: [])
        self.elements   = []
    }
    @inlinable public 
    init(capacity:Int)
    {
        self.init()
        self.elements.reserveCapacity(capacity)
    }
    
    @inlinable public mutating 
    func append(text:String, color:Color)
    {
        self.elements.append(self.storage.store(text: text, color: color))
    }
    
    @inlinable public
    var underestimatedCount:Int 
    {
        self.elements.count
    }
    
    @inlinable public 
    func makeIterator() -> Iterator 
    {
        .init(self.storage, elements: self.elements)
    }
    
    @frozen public 
    struct Iterator:IteratorProtocol 
    {
        public 
        let storage:NotebookStorage, 
            elements:[UInt64]
        public 
        var storageIndex:Int, 
            elementIndex:Int
        
        @inlinable public 
        init(_ storage:NotebookStorage, elements:[UInt64])
        {
            self.storage        = storage 
            self.elements       = elements
            self.storageIndex   = self.storage.utf8.startIndex
            self.elementIndex   = self.elements.startIndex
        }
        
        @inlinable public mutating 
        func next() -> (text:String, color:Color)?
        {
            guard self.elementIndex < self.elements.endIndex 
            else 
            {
                return nil 
            }
            let element:UInt64 = self.elements[self.elementIndex]
            self.elementIndex += 1
            return self.storage.load(element: element, at: &self.storageIndex)
        }
    }
}

@frozen public 
struct Notebook<Color, Link>:Sequence where Color:RawRepresentable, Color.RawValue == UInt8
{
    @frozen public 
    struct Fragment 
    {
        public
        var text:String
        public
        var link:Link?
        public
        var color:Color
        
        @inlinable public
        init(_ text:String, color:Color, link:Link? = nil)
        {
            self.text = text 
            self.color = color 
            self.link = link
        }
    }
    
    @frozen public 
    struct Iterator:IteratorProtocol 
    {
        public 
        var link:(index:Int, target:Link)?
        public 
        var links:Array<(index:Int, target:Link)>.Iterator, 
            content:NotebookContent<Color>.Iterator 
        
        @inlinable public 
        init(_ content:NotebookContent<Color>, links:[(index:Int, target:Link)])
        {
            self.content    = content.makeIterator() 
            self.links      = links.makeIterator()
            self.link       = self.links.next()
        }
        
        @inlinable public mutating 
        func next() -> Fragment?
        {
            let current:Int = self.content.elementIndex
            guard let (text, color):(String, Color) = self.content.next() 
            else 
            {
                return nil 
            }
            if let (index, target):(Int, Link) = self.link, index == current 
            {
                self.link = self.links.next()
                return .init(text, color: color, link: target)
            }
            else 
            {
                return .init(text, color: color)
            }
        }
    }
    
    public 
    var content:NotebookContent<Color>
    public 
    var links:[(index:Int, target:Link)]
    
    @inlinable public
    var underestimatedCount:Int 
    {
        self.content.underestimatedCount
    }
    
    @inlinable public 
    func makeIterator() -> Iterator 
    {
        .init(self.content, links: self.links)
    }
    
    @inlinable public 
    init(capacity:Int)
    {
        self.init(content: .init(capacity: capacity), links: [])
    }
    @inlinable public 
    init(content:NotebookContent<Color>, links:[(index:Int, target:Link)])
    {
        self.content    = content 
        self.links      = links
    }

    @inlinable public 
    init<Fragments>(_ fragments:Fragments) 
        where Fragments:Sequence, Fragments.Element == Fragment
    {
        self.init(capacity: fragments.underestimatedCount)
        for fragment:Fragment in fragments
        {
            if let link:Link = fragment.link 
            {
                self.links.append((self.content.elements.endIndex, link))
            }
            self.content.append(text: fragment.text, color: fragment.color)
        }
    }
    @inlinable public 
    init<Syntax>(_ syntax:Syntax) 
        where Syntax:Sequence, Syntax.Element == (String, Color)
    {
        self.init(capacity: syntax.underestimatedCount)
        for (text, color):(String, Color) in syntax
        {
            self.content.append(text: text, color: color)
        }
    }
    
    @inlinable public 
    func map<T>(_ transform:(Link) throws -> T) rethrows -> Notebook<Color, T>
    {
        .init(content: self.content, links: try self.links.map
        {
            ($0.index, try transform($0.target))
        })
    }
    @inlinable public 
    func compactMap<T>(_ transform:(Link) throws -> T?) rethrows -> Notebook<Color, T>
    {
        .init(content: self.content, links: try self.links.compactMap
        {
            if let transformed:T = try transform($0.target)
            {
                return ($0.index, transformed)
            }
            else 
            {
                return nil 
            }
        })
    }
}
extension Notebook where Link == Never 
{
    // always discards links 
    @inlinable public 
    init<Fragments, Discard>(_ fragments:Fragments) 
        where Fragments:Sequence, Fragments.Element == Notebook<Color, Discard>.Element
    {
        self.init(capacity: fragments.underestimatedCount)
        for fragment:Notebook<Color, Discard>.Element in fragments
        {
            self.content.append(text: fragment.text, color: fragment.color)
        }
    }
}
extension Notebook:Equatable where Link:Equatable
{
    @inlinable public static 
    func == (lhs:Self, rhs:Self) -> Bool 
    {
        guard lhs.content == rhs.content, lhs.links.count == rhs.links.count
        else 
        {
            return false 
        }
        for (lhs, rhs):((Int, Link), (Int, Link)) in zip(lhs.links, rhs.links)
            where lhs != rhs
        {
            return false 
        }
        return true
    }
}
