require 'solrizer/field_name_mapper'

#this class represents a MetadataDatastream, a special case of ActiveFedora::Datastream
module ActiveFedora::MetadataDatastreamHelper 
  
  attr_accessor :fields
  
  module ClassMethods
    
    attr_accessor :xml_model
    
    #get the Class's field list
    def fields
      @@classFields
    end
    
  end
  
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.send(:include, Solrizer::FieldNameMapper)
  end
  
  #constructor, calls up to ActiveFedora::Datastream's constructor
  def initialize(attrs=nil)
    super
    @fields={}
  end
  
  # sets the blob, which in this case is the xml version of self, then calls ActiveFedora::Datastream.save
  def save
    self.set_blob_for_save
    super
  end
  
  def set_blob_for_save # :nodoc:
    self.blob = self.to_xml
  end

  def to_solr(solr_doc = Hash.new) # :nodoc:
    fields.each do |field_key, field_info|
      if field_info.has_key?(:values) && !field_info[:values].nil?
        field_symbol = ActiveFedora::SolrService.solr_name(field_key, field_info[:type])
        field_info[:values].each do |val|    
          ::Solrizer::Extractor.insert_solr_field_value(solr_doc, field_symbol, val )         
        end
      end
    end

    return solr_doc
  end
  
  # ** EXPERIMENTAL **
  #
  # This is utilized by ActiveFedora::Base.load_instance_from_solr to set 
  # metadata values in this object using the Solr document passed in.
  # Any keys in the solr document that map to a metadata field key within a MetadataDatastream object
  # are set to the corresponding value.  Any others are ignored. ActiveFedora::SolrService.solr_name
  # is used to map solr key to field key name.
  #
  # ====Warning
  #  Solr must be synchronized with data in Fedora.
  def from_solr(solr_doc)
    fields.each do |field_key, field_info|
      field_symbol = ActiveFedora::SolrService.solr_name(field_key, field_info[:type])
      value = (solr_doc[field_symbol].nil? ? solr_doc[field_symbol.to_s]: solr_doc[field_symbol]) 
      unless value.nil?
        if value.is_a? Array
          update_attributes({field_key=>value})
        else
          update_indexed_attributes({field_key=>{0=>value}})
        end
      end
    end
  end
  
  def to_xml(xml = Nokogiri::XML::Document.parse("<fields />")) #:nodoc:
    if xml.instance_of?(Nokogiri::XML::Builder)
      xml_insertion_point = xml.doc.root 
    elsif xml.instance_of?(Nokogiri::XML::Document) 
      xml_insertion_point = xml.root
    else
      xml_insertion_point = xml
    end
    
    builder = Nokogiri::XML::Builder.with(xml_insertion_point) do |xml|
      fields.each_pair do |field,field_info|
        element_attrs = field_info[:element_attrs].nil? ? {} : field_info[:element_attrs]
        field_info[:values].each do |val|
          builder_arg = "xml.#{field}(val, element_attrs)"
          eval(builder_arg)
        end
      end
    end
    return builder.to_xml
  end

end