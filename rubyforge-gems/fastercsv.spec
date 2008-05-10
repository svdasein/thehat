# Generated from fastercsv-1.2.3.gem by gem2rpm -*- rpm-spec -*-
%define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemname fastercsv
%define geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary: FasterCSV is CSV, but faster, smaller, and cleaner
Name: rubygem-%{gemname}
Version: 1.2.3
Release: 1%{?dist}
Group: Development/Languages
License: GPLv2+ or Ruby
URL: http://fastercsv.rubyforge.org
Source0: http://gems.rubyforge.org/gems/%{gemname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(id -u)
Requires: rubygems
#BuildRequires: rubygems
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
FasterCSV is intended as a complete replacement to the CSV standard library.
It is significantly faster and smaller while still being pure Ruby code. It
also strives for a better interface.


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
%doc %{geminstdir}/AUTHORS
%doc %{geminstdir}/COPYING
%doc %{geminstdir}/README
%doc %{geminstdir}/INSTALL
%doc %{geminstdir}/TODO
%doc %{geminstdir}/CHANGELOG
%doc %{geminstdir}/LICENSE
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec


%changelog
* Sat May 10 2008 dave,,, <dave@professor> - 1.2.3-1
- Initial package
