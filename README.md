What is this?
-------------

This iOS app demonstrates a regression in behaviour of `NSFetchedResultsController` on iOS 9.0 and later related to updates processing. In particular scenarios, the controller would generate a delegate callback about a bogus `NSFetchedResultsChangeMove` between some index and the same index. While effectively this means "nothing happened", this is somewhat a contract breach for the delegate notifications and may cause issues.

More details are in [this Radar](http://www.openradar.me/radar?id=5678834951127040).
