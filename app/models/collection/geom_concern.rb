module Collection::GeomConcern
  def compute_center
    root_sites.select('sum(lat) as v1, sum(lng) as v2, count(*) as v3').each do |v|
      if v.v1 && v.v2 && v.v3
        self.lat = v.v1 / v.v3
        self.lng = v.v2 / v.v3
      end
    end
  end

  def compute_center!
    compute_center
    save!
  end
end