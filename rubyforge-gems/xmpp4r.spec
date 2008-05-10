# Generated from xmpp4r-0.3.2.gem by gem2rpm -*- rpm-spec -*-
%define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemname xmpp4r
%define geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary: Ruby library for Jabber Instant-Messaging
Name: rubygem-%{gemname}
Version: 0.3.2
Release: 1%{?dist}
Group: Development/Languages
License: GPLv2+ or Ruby
#URL: 
Source0: http://gems.rubyforge.org/gems/%{gemname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(id -u)
Requires: rubygems
#BuildRequires: rubygems
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
Ruby library for Jabber Instant-Messaging


%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
gem install --local --install-dir %{buildroot}%{gemdir} \
            --force %{SOURCE0}

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%{gemdir}/gems/%{gemname}-%{version}/
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec


%changelog
* Sat May 10 2008 dave,,, <dave@professor> - 0.3.2-1
- Initial package
