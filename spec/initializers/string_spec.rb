require 'spec_helper'

describe String do
  let(:template_string) { 'Dear [name], your balance is now [money].' }

  it "render a string from a template string" do
    expect(template_string.render_template_string({'name' => 'Dane', 'money' => '10$'})).to eq('Dear name, your balance is now money.')
  end
end

