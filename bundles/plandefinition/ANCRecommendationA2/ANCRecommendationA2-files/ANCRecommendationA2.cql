library ANCRecommendationA2 version '0.1.0'

/*
IAF - Iron and Folic Acid Supplements

RECOMMENDATION A.2.1: Daily oral iron and folic acid supplementation with 30 mg to
60 mg of elemental iron and 400 &mu;g (0.4 mg) folic acid is recommended for pregnant
women to prevent maternal anaemia, puerperal sepsis, low birth weight, and preterm birth.
(Recommended)
*/

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers

codesystem LOINC: 'http://loinc.org'

valueset "Haemoglobin Tests": 'http://fhir.org/guides/who/anc-cds/ValueSet/haemoglobin-tests'
valueset "Pregnancy Expected Delivery Date Method - IPS": 'http://hl7.org/fhir/uv/ips/ValueSet/edd-method-uv-ips'

code "Pregnancy status": '82810-3' from LOINC display 'Pregnancy status'
code "Pregnancy status - Pregnant": 'LA15173-0' from LOINC display 'Pregnant'
code "Delivery date Estimated from last menstrual period": '11779-6' from LOINC display 'Delivery date Estimated from last menstrual period'

parameter "Reference Date" DateTime 
  // default  @2024-01-01 // for testing within this ExecuteCQL
  default Today() // for testing within a CQL Testing Framework project

context Patient

define "Alive": 
  case 
    // when Patient.deceased = true then false //redundant
    when Patient.deceased = false then true
    // when "Null Patient.deceased assumed to mean alive" = true and Patient.deceased is null then true // default is false. Your dead unless you the records says you are not. 
    else false
  end

define Active: 
  if Patient.active = true then true
	else false

/*
On every contact,
  if anaemia detected
    recommend 120 mg of elemental iron and 400 &mu;g of folic acid daily (Recommendation A.2.1)
  else
    recommend 30 to 60 mg of elemental iron and 400 &mu;g of folic acid, daily (Recommendation A.2.1)

Has Anaemia
  Hb Concentration < 11 g/dL and Gestational Age < 12 weeks or Gestational Age > 28 weeks
  Hb Concentration < 10.5 g/dL and Gestational Age between 13 weeks and 27 weeks
*/

define "Has Anaemia":
  if "Gestational Age in Weeks" between 13 and 27 then
    "Hb Concentration" < 10.5 'g/dL'
  else
    "Hb Concentration" < 11 'g/dL'

// define "Pregnant":
//     "Pregnancy Status" ~ "Pregnancy status - Pregnant"

define "Pregnant":
  exists([Observation: "Pregnancy status"] O
    where O.status = 'final'
    and O.value ~ "Pregnancy status - Pregnant" // Pregnant
    and O.effective <= "Reference Date")
  and ("Estimated Due Date" > "Reference Date")

define "Pregnancy Status":
  FHIRHelpers.ToConcept(
    First(
      [Observation: "Pregnancy status"] O
        where O.status = 'final'
        sort by FHIRHelpers.ToDateTime(effective as FHIR.dateTime)
    ).value
  )

define "Estimated Due Date":
  FHIRHelpers.ToDateTime(
    First(
      [Observation: "Pregnancy Expected Delivery Date Method - IPS"] O
        where O.status = 'final'
          and FHIRHelpers.ToDateTime(O.issued) 1 year or less before "Reference Date"
        sort by FHIRHelpers.ToDateTime(effective as FHIR.dateTime) desc
    ).value
  )

define "Gestational Age in Weeks":
  weeks between ("Estimated Due Date" - 9 months - 7 days) and "Reference Date"

define "Hb Concentration":
  FHIRHelpers.ToQuantity(
    First(
      ["Observation": "Haemoglobin Tests"] O
  		  where O.status = 'final'
        sort by FHIRHelpers.ToDateTime(effective as FHIR.dateTime) descending
    ).value
  )

define "Is Recommendation Applicable":
  "Pregnant"

define "Get Card Summary":
  if "Has Anaemia" then
    'Recommend 120 mg elemental iron and 0.4 mg folic acid, daily'
  else
    'Recommend 30-60 mg elemental iron and 0.4 mg folic acid, daily'

define "Get Card Detail":
  if "Has Anaemia" then
    'Daily elemental iron should be increased to 120 mg, and daily dose of 400 ug (0.4 mg) until her Hb concentration rises to normal'
  else
    'Daily elemental iron of between 30m and 60mg, and daily dose of 400 ug (0.4 mg) of folic acid is recommended for pregnant women'

define "Get Card Indicator":
  if "Has Anaemia" then
    'warning'
  else
    'info'
