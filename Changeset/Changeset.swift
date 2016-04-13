//
//  Changeset.swift
//  Copyright (c) 2015 Joachim Bondo. All rights reserved.
//

/// Defines an atomic edit.
/// - seealso: Note on `Operation`.
public struct Edit {
	public enum Operation {
		case Insertion
		case Deletion
		case Substitution
		case Move(origin: Int)
	}
	
	public let operation: Operation
	public let destination: Int
	
	// Define initializer so that we don't have to add the `operation` label.
	public init(_ operation: Operation, destination: Int) {
		self.operation = operation
		self.destination = destination
	}
}

/// A `Changeset` is a way to describe the edits required to go from one set of data to another.
///
/// It detects additions, deletions, substitutions, and moves. Data is a `CollectionType` of `Equatable` elements.
///
/// - note: This implementation was inspired by [Dave DeLong](https://twitter.com/davedelong)'s article, [Edit distance and edit steps](http://davedelong.tumblr.com/post/134367865668/edit-distance-and-edit-steps).
///
/// - seealso: `Changeset.editDistance`.
public struct Changeset<T: CollectionType where T.Generator.Element: Equatable, T.Index.Distance == Int> {
	
	/// The starting-point collection.
	public let origin: T
	
	/// The ending-point collection.
	public let destination: T
	
	/// The edit steps required to go from `self.origin` to `self.destination`.
	/// - note: I would have liked to make this `lazy`, but that would prohibit users from using constant `Changeset` values.
	/// - seealso: [Lazy Properties in Structs](http://oleb.net/blog/2015/12/lazy-properties-in-structs-swift/) by [Ole Begemann](https://twitter.com/olebegemann).
	public let edits: [Edit]
	
	public init(source origin: T, target destination: T) {
		self.origin = origin
		self.destination = destination
		self.edits = Changeset.editDistance(source: self.origin, target: self.destination)
	}
	
	/// Returns the edit steps required to go from `source` to `target`.
	///
	/// - note: Indexes in the returned `Edit` elements are into the `source` collection (just like how `UITableView` expects changes in the `beginUpdates`/`endUpdates` block.)
	///
	/// - seealso:
	///   - [Edit distance and edit steps](http://davedelong.tumblr.com/post/134367865668/edit-distance-and-edit-steps) by [Dave DeLong](https://twitter.com/davedelong).
	///   - [Explanation of and Pseudo-code for the Wagner-Fischer algorithm](https://en.wikipedia.org/wiki/Wagner–Fischer_algorithm).
	///
	/// - parameters:
	///   - source: The starting-point collection.
	///   - target: The ending-point collection.
	///
	/// - returns: An array of `Edit` elements.
	/// The number of steps is then the `count` of elements.
	public static func editDistance(source s: T, target t: T) -> [Edit] {
		
		let m = s.count
		let n = t.count
		
		// Fill first row and column of insertions and deletions.
		
		var d: [[[Edit]]] = Array(count: m + 1, repeatedValue: Array(count: n + 1, repeatedValue: []))
		
		var edits = [Edit]()
		for (row, element) in s.enumerate() {
			let deletion = Edit(.Deletion, destination: row)
			edits.append(deletion)
			d[row + 1][0] = edits
		}
		
		edits.removeAll()
		for (col, element) in t.enumerate() {
			let insertion = Edit(.Insertion, destination: col)
			edits.append(insertion)
			d[0][col + 1] = edits
		}
		
		guard m > 0 && n > 0 else { return d[m][n] }
		
		// Indexes into the two collections.
		var sx: T.Index
		var tx = t.startIndex
		
		// Fill body of matrix.
		
		for j in 1...n {
			sx = s.startIndex
			
			for i in 1...m {
				if s[sx] == t[tx] {
					d[i][j] = d[i - 1][j - 1] // no operation
				} else {
					
					var del = d[i - 1][j] // a deletion
					var ins = d[i][j - 1] // an insertion
					var sub = d[i - 1][j - 1] // a substitution
					
					// Record operation.
					
					let minimumCount = min(del.count, ins.count, sub.count)
					if del.count == minimumCount {
						let deletion = Edit(.Deletion, destination: i - 1)
						del.append(deletion)
						d[i][j] = del
					} else if ins.count == minimumCount {
						let insertion = Edit(.Insertion, destination: j - 1)
						ins.append(insertion)
						d[i][j] = ins
					} else {
						let substitution = Edit(.Substitution, destination: i - 1)
						sub.append(substitution)
						d[i][j] = sub
					}
				}
				
				sx = sx.advancedBy(1)
			}
			
			tx = tx.advancedBy(1)
		}
		
		// Convert deletion/insertion pairs of same element into moves.
		return d[m][n]
	}
}


extension Edit: Equatable {}
public func ==(lhs: Edit, rhs: Edit) -> Bool {
	guard lhs.destination == rhs.destination  else { return false }
	switch (lhs.operation, rhs.operation) {
	case (.Insertion, .Insertion), (.Deletion, .Deletion), (.Substitution, .Substitution):
		return true
	case (.Move(let lhsOrigin), .Move(let rhsOrigin)):
		return lhsOrigin == rhsOrigin
	default:
		return false
	}
}
