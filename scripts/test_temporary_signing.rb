require_relative 'temporary_signing'

class TemporarySigningTest
  def certificate(team = 'TEAM123', cn = 'Apple Development: CI')
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{cn}/OU=#{team}")
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 10
    cert.not_after = Time.now + 3600
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    cert
  end

  def row(id, cert, type = 'DEVELOPMENT')
    {'id' => id, 'attributes' => {'certificateType' => type, 'certificateContent' => Base64.strict_encode64(cert.to_der)}}
  end

  def fingerprint(cert)
    OpenSSL::Digest::SHA1.hexdigest(cert.to_der).upcase
  end

  def test_only_new_local_team_development_identity_is_selected
    owned, other, old, distribution, wrong_team, prior_local = [certificate, certificate, certificate, certificate('TEAM123', 'Apple Distribution: CI'), certificate('OTHER'), certificate]
    rows = [row('owned', owned), row('other-run', other), row('existing', old), row('distribution', distribution, 'DISTRIBUTION'), row('wrong-team', wrong_team), row('prior-local', prior_local)]
    result = TemporarySigning.candidates(before_ids: Set['existing'], before_local: Set[fingerprint(prior_local)],
      after_remote: rows, after_local: [owned, old, distribution, wrong_team, prior_local].map { |c| fingerprint(c) }.to_set,
      team: 'TEAM123', started: Time.now)
    raise 'Unsafe certificate selection' unless result.map { |r| r['id'] } == ['owned']
    puts 'PASS: only newly issued local development identity selected'
  end
  def test_retry_is_limited_to_the_same_verified_certificate
    requests = []
    original_request = TemporarySigning.method(:request)
    TemporarySigning.define_singleton_method(:request) do |method, url|
      requests << [method, url]
      raise TemporarySigning::RetryableAPIError if requests.length < 3
    end
    TemporarySigning.define_singleton_method(:sleep) { |_| }
    TemporarySigning.revoke_verified('owned')
    expected = [:delete, "https://#{TemporarySigning::HOST}/v1/certificates/owned"]
    raise 'Unexpected certificate retry' unless requests == [expected, expected, expected]
    puts 'PASS: transient failures retry only the verified certificate'
  ensure
    TemporarySigning.define_singleton_method(:request, original_request)
    TemporarySigning.singleton_class.remove_method(:sleep)
  end

end

TemporarySigningTest.new.test_only_new_local_team_development_identity_is_selected
TemporarySigningTest.new.test_retry_is_limited_to_the_same_verified_certificate
