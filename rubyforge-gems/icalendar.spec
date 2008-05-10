# Generated from icalendar-1.0.2.gem by gem2rpm -*- rpm-spec -*-
%define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemname icalendar
%define geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary: A ruby implementation of the iCalendar specification (RFC-2445)
Name: rubygem-%{gemname}
Version: 1.0.2
Release: 1%{?dist}
Group: Development/Languages
License: GPLv2+ or Ruby
URL: http://icalendar.rubyforge.org/
Source0: http://gems.rubyforge.org/gems/%{gemname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(id -u)
Requires: rubygems
#BuildRequires: rubygems
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
Implements the iCalendar specification (RFC-2445) in Ruby.  This allows for
the generation and parsing of .ics files, which are used by a variety of
calendaring applications.


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
%doc %{geminstdir}/README
%doc %{geminstdir}/COPYING
%doc %{geminstdir}/GPL
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec


%changelog
* Sat May 10 2008 dave,,, <dave@professor> - 1.0.2-1
- Initial package
