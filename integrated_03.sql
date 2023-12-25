USE md_water_serviceso;

/*Created a table for an audit report and populated it with data from a csv file. The audit was done to confirm
the data reported by the surveyor in order to be sure that the right sources should be improved.*/

DROP TABLE IF EXISTS auditor_report;
CREATE TABLE auditor_report(
	location_id VARCHAR(32),
	type_of_water_source VARCHAR(64),
    true_water_source_score int DEFAULT NULL,
    statements VARCHAR(255)
);


/*This query was used to get the incorrectly filled data for quality score column
by comparing the surveyor score for quality of water with that of the auditor's report
using JOIN statements
*/
SELECT
	visits.record_id,
	auditor_report.location_id,
    auditor_report.true_water_source_score AS auditor_score,
    water_quality.subjective_quality_score AS employee_score
    
    /*Confirming if the water source are the same*/
    
    -- water_source.type_of_water_source AS survey_source,
    -- auditor_report.type_of_water_source AS auditor_source
FROM
	auditor_report
JOIN visits 
	ON auditor_report.location_id = visits.location_id
JOIN water_quality 
	ON visits.record_id = water_quality.record_id
-- JOIN water_source
	-- ON visits.source_id = water_source.source_id
WHERE 
	water_quality.subjective_quality_score != auditor_report.true_water_source_score
    AND visits.visit_count = 1;
  

/*This query was used to get the number of mistakes made by each employee ordered from highest to lowest
using a CTEs to generate the incorrect records
*/
WITH incorrect_records AS (SELECT
	visits.record_id,
	auditor_report.location_id,
    auditor_report.true_water_source_score AS auditor_score,
    water_quality.subjective_quality_score AS employee_score,
    employee.employee_name
FROM
	auditor_report
JOIN visits 
	ON auditor_report.location_id = visits.location_id
JOIN water_quality 
	ON visits.record_id = water_quality.record_id
JOIN employee
	ON visits.assigned_employee_id = employee.assigned_employee_id
WHERE 
	water_quality.subjective_quality_score != auditor_report.true_water_source_score
    AND visits.visit_count = 1
    ) SELECT 
		/*this gives the number of employees that faulted*/
		-- COUNT(DISTINCT(incorrect_records.employee_name)) 
        incorrect_records.employee_name,
        COUNT(incorrect_records.employee_name) AS number_of_mistakes
	FROM 
		incorrect_records
	GROUP BY 
		incorrect_records.employee_name
	ORDER BY 
		number_of_mistakes DESC;
        

/*Created a view for the incorrect records to make it resusable to make it reusable to calculate the average 
mistakes made based on the number of times the employee name occurs
*/
DROP VIEW IF EXISTS incorrect_records;
CREATE VIEW incorrect_records AS (SELECT
	visits.record_id,
	auditor_report.location_id,
	auditor_report.true_water_source_score AS auditor_score,
	water_quality.subjective_quality_score AS employee_score,
	employee.employee_name,
    auditor_report.statements
FROM
	auditor_report
JOIN visits 
	ON auditor_report.location_id = visits.location_id
JOIN water_quality 
	ON visits.record_id = water_quality.record_id
JOIN employee
	ON visits.assigned_employee_id = employee.assigned_employee_id
WHERE 
	water_quality.subjective_quality_score != auditor_report.true_water_source_score
    AND visits.visit_count = 1
); 


/*The error_count CTE returns a table of employees names and the number of incorrect record
	which is then filtered by the outer query based on the those employee 
	who made more than the average error
*/

WITH error_count AS (SELECT 
	incorrect_records.employee_name,
	COUNT(incorrect_records.employee_name) AS number_of_mistakes
FROM 
	/*
		Incorrect_records is a view that joins the audit report to the database
		for records where the auditor and
		employees scores are different*
	*/
	incorrect_records
GROUP BY 
	incorrect_records.employee_name
ORDER BY 
	number_of_mistakes DESC
	)SELECT
		employee_name,
        number_of_mistakes
	FROM
		error_count
	WHERE
    -- returns the number of mistakes greater than the average number of mistakes
		number_of_mistakes > (
        SELECT
			AVG(number_of_mistakes)
		FROM
			error_count
	);
    

/*Created a view for error_count inorder to make the table reusable and for more dynamic result*/
CREATE VIEW error_count AS (SELECT 
	incorrect_records.employee_name,
	COUNT(incorrect_records.employee_name) AS number_of_mistakes
FROM 
	incorrect_records
GROUP BY 
	incorrect_records.employee_name
ORDER BY 
	number_of_mistakes DESC
);

/*Created a suspect list CTE where by the inner query returns a table of employee_name and number_of_mistakes 
	filtering based on mistakes greater than the average from the error_count view which the CTE outer query
    use to filter down the incorrect record view to return the employee_name, location_id and statements.
    The statements was then filtered based on the word 'cash' to reveal the scandal
*/
WITH suspect_list AS (SELECT
		employee_name,
        number_of_mistakes
	FROM
		error_count
	WHERE
	number_of_mistakes > (
	SELECT
		AVG(number_of_mistakes)
	FROM
		error_count
)
)SELECT
	employee_name,
    location_id,
    statements
FROM
	incorrect_records
WHERE
	employee_name IN (SELECT employee_name FROM suspect_list)
     AND statements NOT LIKE "%cash%";
    
/*Alternative solution to the above*/

WITH error_count AS (SELECT 
	incorrect_records.employee_name,
	COUNT(incorrect_records.employee_name) AS number_of_mistakes
FROM 
	/*
		Incorrect_records is a view that joins the audit report to the database
		for records where the auditor and
		employees scores are different*
	*/
	incorrect_records
GROUP BY 
	incorrect_records.employee_name
ORDER BY 
	number_of_mistakes DESC
	), suspect_list AS (SELECT
		employee_name,
        number_of_mistakes
	FROM
		error_count
	WHERE
    -- returns the number of mistakes greater than the average number of mistakes
		number_of_mistakes > (
        SELECT
			AVG(number_of_mistakes)
		FROM
			error_count
	)
    )SELECT
		employee_name,
        location_id,
        statements
	FROM
		incorrect_records
	WHERE
		/*Checking if any other employee not in suspect list had the same cash scandal*/
		-- employee_name NOT IN (SELECT employee_name FROM suspect_list)
		employee_name IN (SELECT employee_name FROM suspect_list)
        AND statements LIKE "%cash%"
    