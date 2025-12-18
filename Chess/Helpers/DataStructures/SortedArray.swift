//
//  SortedArray.swift
//  Chess
//
//  Created by Oleg Kovtun on 18.12.2025.
//


struct SortedArray<Element: Comparable & Hashable> {
    private(set) var elements: [Element]
    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }
    var last: Element? { elements.last }
    var first: Element? { elements.first }
    
    init<S: Sequence>(_ unsorted: S) where S.Iterator.Element == Element, S.Element == Element {
        elements = unsorted.sorted()
    }
    
    subscript(_ i: Int) -> Element {
        elements[i]
    }
    
    private func index(for element: Element) -> Int {
        var start = elements.startIndex
        var end = elements.endIndex
        while start < end {
            let middle = start + (end - start) / 2
            if elements[middle] < element {
                start = middle + 1
            } else {
                end = middle
            }
        }
        return start
    }
    
    mutating func insert(_ element: Element) {
        elements.insert(element, at: index(for: element))
    }
    
    mutating func remove(_ element: Element) {
        elements.remove(at: index(for: element))
    }
    
    func contains(_ element: Element) -> Bool {
        let index = self.index(for: element)
        guard index < elements.endIndex else { return false }
        return elements[index] == element
    }
}
