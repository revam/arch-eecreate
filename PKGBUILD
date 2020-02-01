# Maintainer: Mikal Stordal <mikalstordal at gmail dot com>

pkgname=eecreate-git
pkgver=0.r1.0000000
pkgrel=1
pkgdesc="Create bottable (U)EFI executables."
conflicts=('eecreate')
provides=('eecreate')
arch=('any')
url="https://github.com/revam/arch-eecreate"
license=('GPL3')
depends=('bash' 'systemd' 'binutils')
makedepends=('git')
source=("project::git+https://github.com/revam/arch-eecreate.git")
sha256sums=('SKIP')
contributor=('revam')

pkgver() {
  printf "0.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
  cd project
  install -D -m 0755 eecreate.sh "${pkgdir}/usr/bin/eecreate"
  install -D -m 0644 readme.md "${pkgdir}/usr/share/doc/${pkgname}/readme.md"
}

# vim:set ts=2 sw=2 et:
