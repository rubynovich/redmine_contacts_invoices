require File.expand_path('../../test_helper', __FILE__)

class InvoiceLineTest < ActiveSupport::TestCase

  def test_accepts_numbers_with_commas
    line = InvoiceLine.new(:description => 'desc', :price => '123,45', :quantity => '1,2')
    assert line.valid?, 'Should be valid'
    assert_equal line.price, 123.45
    assert_equal line.quantity, 1.2
  end

  def test_should_not_accepts_empty_numbers
    line = InvoiceLine.new(:description => 'desc', :price => '123,45', :quantity => '')
    assert !line.valid?, 'Should be valid'
  end  
end
