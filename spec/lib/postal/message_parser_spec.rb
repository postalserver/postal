# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageParser do
  let(:server) { create(:server) }

  it "should not do anything when there are no tracking domains" do
    expect(server.track_domains.size).to eq 0
    message = create_plain_text_message(server, "Hello world!", "test@example.com")
    parser = Postal::MessageParser.new(message)
    expect(parser.actioned?).to be false
    expect(parser.tracked_links).to eq 0
    expect(parser.tracked_images).to eq 0
  end

  it "should replace links in messages" do
    message = create_plain_text_message(server, "Hello world! http://github.com/atech/postal", "test@example.com")
    create(:track_domain, server: server, domain: message.domain)
    parser = Postal::MessageParser.new(message)
    expect(parser.actioned?).to be true
    expect(parser.new_body).to match(/^Hello world! https:\/\/click\.#{message.domain.name}/)
    expect(parser.tracked_links).to eq 1
  end

  it "should not treat a multipart/related container with a type parameter as an HTML part" do
    message = create_plain_text_message(server, "Hello world!", "test@example.com")
    create(:track_domain, server: server, domain: message.domain)

    raw = <<~MESSAGE.gsub("\n", "\r\n")
      From: test@#{message.domain.name}
      To: test@example.com
      Subject: Inline image test
      MIME-Version: 1.0
      Content-Type: multipart/alternative;
       boundary="alt-boundary"

      --alt-boundary
      Content-Type: text/plain; charset=utf-8

      Hello world!
      --alt-boundary
      Content-Type: multipart/related;
       boundary="rel-boundary";
       type="text/html"

      --rel-boundary
      Content-Type: text/html; charset=utf-8

      <html><body><p>Hello world!</p><img src="cid:img1"></body></html>
      --rel-boundary
      Content-Type: image/png; name=chart.png
      Content-ID: <img1>
      Content-Transfer-Encoding: base64
      Content-Disposition: inline; filename=chart.png

      iVBORw0KGgo=
      --rel-boundary--

      --alt-boundary--
    MESSAGE
    allow(message).to receive(:raw_message).and_return(raw)

    parser = Postal::MessageParser.new(message)

    parsed = Mail.new("#{parser.new_headers}\r\n\r\n#{parser.new_body}")
    related = parsed.parts.detect { |p| p.mime_type == "multipart/related" }
    expect(related).to_not be_nil
    expect(related.parts.map(&:mime_type)).to match_array(["text/html", "image/png"])

    html_part = related.parts.detect { |p| p.mime_type == "text/html" }
    expect(html_part.body.decoded).to include("img/#{server.token}/#{message.token}")

    image_part = related.parts.detect { |p| p.mime_type == "image/png" }
    expect(image_part.content_id).to eq "<img1>"
  end
end
