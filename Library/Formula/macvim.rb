require 'formula'

class Macvim < Formula
  homepage 'http://code.google.com/p/macvim/'
  url 'https://github.com/b4winckler/macvim/tarball/snapshot-57'
  version '7.3-57'
  md5 '2bf4630be2d59f62b8b70870ba1fe0a1'
  head 'https://github.com/b4winckler/macvim.git', :branch => 'master'

  def options
  [
    # Building custom icons fails for many users, so off by default.
    ["--custom-icons", "Try to generate custom document icons."],
    ["--with-cscope", "Build with Cscope support."],
    ["--with-envycoder", "Build with Envy Code R Bold font."],
    ["--override-system-vim", "Override system vim"]
  ]
  end

  depends_on 'cscope' if ARGV.include? '--with-cscope'

  def install
    # MacVim's Xcode project gets confused by $CC, so remove it
    ENV['CC'] = nil
    ENV['CFLAGS'] = nil
    ENV['CXX'] = nil
    ENV['CXXFLAGS'] = nil

    # Set ARCHFLAGS so the Python app (with C extension) that is
    # used to create the custom icons will not try to compile in
    # PPC support (which isn't needed in Homebrew-supported systems.)
    arch = MacOS.prefer_64_bit? ? 'x86_64' : 'i386'
    ENV['ARCHFLAGS'] = "-arch #{arch}"

    args = ["--with-macsdk=#{MACOS_VERSION}",
           "--with-features=huge",
           "--with-macarchs=#{arch}",
           "--enable-perlinterp",
           "--enable-pythoninterp",
           "--enable-rubyinterp",
           "--enable-tclinterp"]

    args << "--enable-cscope" if ARGV.include? "--with-cscope"

    system "./configure", *args

    unless ARGV.include? "--custom-icons"
      inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
      inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    end

    if ARGV.include? "--with-envycoder"
      # Font download location has changed.
      # This is fixed in MacVim trunk, but not in the stable tarball.
      inreplace "src/MacVim/icons/Makefile",
        "http://download.damieng.com/latest/EnvyCodeR",
        "http://download.damieng.com/fonts/original/EnvyCodeR-PR7.zip"
    else
      # Remove the font from the build dependencies
      inreplace "src/MacVim/icons/Makefile",
        '$(OUTDIR)/MacVim-generic.icns: make_icons.py vim-noshadow-512.png loadfont.so Envy\ Code\ R\ Bold.ttf',
        "$(OUTDIR)/MacVim-generic.icns: make_icons.py vim-noshadow-512.png loadfont.so"
    end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
              "VIM_APP_DIR=#{prefix}"
    bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    executables = %w[mvimdiff mview mvimex]
    executables += %w[vi vim vimdiff view vimex] if ARGV.include? "--override-system-vim"
    executables.each {|f| ln_s bin+'mvim', bin+f}
  end

  def caveats; <<-EOS.undent
    MacVim.app installed to:
      #{prefix}

    To link the application to a normal Mac OS X location:
        brew linkapps
    or:
        sudo ln -s #{prefix}/MacVim.app /Applications
    EOS
  end
end
