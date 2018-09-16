module JobsHelper
  def mail_class_options
    [
      ['1st Class Presort','firstpresort'],
      ['1st Class Straight','firststraight'],
      ['1st Class Comingle','firstcommingle'],
      ['Standard Entry Point','standard'],
      ['Standard Commingle', 'standardcommingle'],
      ['Standard Drop Ship','standarddropship'],
      ['Non-Profit Entry Point','standardnonprofit'],
      ['Non Profit Drop Ship','nonprofitdropship'],
      ['Non-Profit Commingle', 'nonprofitcommingle']
    ]
  end

  def mail_type_options
    [
      ['First Class Card', 46],
      ['First Class Flats', 41],
      ['First Class Letter', 40],
      ['Periodical Flats', 45],
      ['Periodical Letters', 44],
      ['Standard Cards', 47],
      ['Standard Flats', 43],
      ['Standard Letters', 42]
    ]
  end
end
