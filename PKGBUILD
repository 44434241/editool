# Maintainer: bbbb-b <nullptr@inbox.lt>

pkgname='editool-git'
pkgver=r39.03bc2db
pkgrel=1
pkgdesc="Tool for editing things"
arch=(x86_64) 
url="https://github.com/44434241/editool"
license=('GPL3') 
depends=('ripgrep' 'fd')
makedepends=('git')
provides=()
conflicts=()
replaces=()
backup=()
options=()
source=("$pkgname::git+https://github.com/44434241/editool")
noextract=()
md5sums=("SKIP")

pkgver() {
	cd "$pkgname"
	printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)" 
	# change to last commit date? 
}

package() {
	cd "$pkgname"
	git submodule update --force --init 
	bash all_is_ok.sh
	mkdir -p "$pkgdir/opt/" "$pkgdir/usr/bin/"
	install editool.ok "$pkgdir/opt/editool"
	ln -s "$pkgdir/opt/editool" "$pkgdir/usr/bin/edit"
}