import Foundation

struct IFAddrInfo {
	let isUp: Bool
	let isRunning: Bool
	let isLoopback: Bool

	let familyRaw: UInt8
	let family: Family?

	enum Family {
		case ip4
		case ip6
	}

	let name: String

	let rawAddress: String
}

extension IFAddrInfo {
	init?(from interface: ifaddrs) {
		let flags = interface.ifa_flags
		let isUp = (flags & UInt32(IFF_UP)) != 0
		let isRunning = (flags & UInt32(IFF_RUNNING)) != 0
		let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0

		guard let addr = interface.ifa_addr else { return nil }
		let familyRaw = addr.pointee.sa_family

		let family: Family?
		switch familyRaw {
		case UInt8(AF_INET):
			family = .ip4
		case UInt8(AF_INET6):
			family = .ip6
		default: family = nil
		}

		let name = String(cString: interface.ifa_name)

		var strCharArray = [CChar](repeating: 0, count: Int(NI_MAXHOST))
		let sockaddrSize = socklen_t(interface.ifa_addr.pointee.sa_len)
		getnameinfo(
			interface.ifa_addr,
			sockaddrSize,
			&strCharArray,
			socklen_t(strCharArray.count),
			nil,
			socklen_t(0),
			NI_NUMERICHOST)

		let address = String(cString: &strCharArray)

		self.init(
			isUp: isUp,
			isRunning: isRunning,
			isLoopback: isLoopback,
			familyRaw: familyRaw,
			family: family,
			name: name,
			rawAddress: address)
	}
}
