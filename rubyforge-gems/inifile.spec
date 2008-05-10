# Generated from inifile-0.1.0.gem by gem2rpm -*- rpm-spec -*-
%define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemname inifile
%define geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary: INI file reader and writer
Name: rubygem-%{gemname}
Version: 0.1.0
Release: 1%{?dist}
Group: Development/Languages
License: GPLv2+ or Ruby
Source0: http://gems.rubyforge.org/gems/%{gemname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(id -u)
Requires: rubygems
#BuildRequires: rubygems
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
Although made popular by Windows, INI files can be used on any system thanks
to their flexibility. They allow a program to store configuration data, which
can then be easily parsed and changed. Two notable systems that use the INI
format are Samba and Trac.  This is a native Ruby package for reading and
writing INI files.


%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
gem install --local --install-dir %{buildroot}%{gemdir} \
            --force --rdoc %{SOURCE0}

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%{gemdir}/gems/%{gemname}-%{version}/
%doc %{gemdir}/doc/%{gemname}-%{version}
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec


%changelog
* Sat May 10 2008 dave,,, <dave@professor> - 0.1.0-1
- Initial package
