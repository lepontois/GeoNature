-- Trigger générique de calcule de l'altitude (calcule si l'altittude n'est pas postée)
CREATE OR REPLACE FUNCTION ref_geo.fct_trg_calculate_alt_minmax()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
	the4326geomcol text := quote_ident(TG_ARGV[0]);
  thelocalsrid int;
BEGIN
	-- si c'est un insert et que l'altitude min ou max est null -> on calcule
	IF (TG_OP = 'INSERT' and (new.altitude_min IS NULL or new.altitude_max IS NULL)) THEN 
		--récupérer le srid local
		SELECT INTO thelocalsrid parameter_value::int FROM gn_commons.t_parameters WHERE parameter_name = 'local_srid';
		--Calcul de l'altitude
		
    SELECT (ref_geo.fct_get_altitude_intersection(st_transform(hstore(NEW)-> the4326geomcol,thelocalsrid))).*  INTO NEW.altitude_min, NEW.altitude_max;
    -- si c'est un update et que la geom a changé
  ELSIF (TG_OP = 'UPDATE' AND NOT public.ST_EQUALS(hstore(OLD)-> the4326geomcol, hstore(NEW)-> the4326geomcol)) then
	 -- on vérifie que les altitude ne sont pas null 
   -- OU si les altitudes ont changé, si oui =  elles ont déjà été calculés - on ne relance pas le calcul
	   IF (new.altitude_min is null or new.altitude_max is null) OR (NOT OLD.altitude_min = NEW.altitude_min or NOT OLD.altitude_max = OLD.altitude_max) THEN 
	   --récupérer le srid local	
	   SELECT INTO thelocalsrid parameter_value::int FROM gn_commons.t_parameters WHERE parameter_name = 'local_srid';
		--Calcul de l'altitude
        SELECT (ref_geo.fct_get_altitude_intersection(st_transform(hstore(NEW)-> the4326geomcol,thelocalsrid))).*  INTO NEW.altitude_min, NEW.altitude_max;
	   end IF;
	 else 
	 END IF;
  RETURN NEW;
END;
$function$
;

-- application du trigger sur occtax
CREATE TRIGGER tri_calculate_altitude
  BEFORE INSERT OR UPDATE
  ON pr_occtax.t_releves_occtax
  FOR EACH ROW
  EXECUTE PROCEDURE ref_geo.fct_trg_calculate_alt_minmax('geom_4326');


-- Création de la table necessaire au MAJ mobiles
CREATE TABLE gn_commons.t_mobile_apps(
  id_mobile_app serial,
  app_code character varying(30),
  relative_path_apk character varying(255),
  url_apk character varying(255)
);

COMMENT ON COLUMN gn_commons.t_mobile_apps.app_code IS 'Code de l''application mobile. Pas de FK vers t_modules car une application mobile ne correspond pas forcement à un module GN';

ALTER TABLE ONLY gn_commons.t_mobile_apps
    ADD CONSTRAINT pk_t_moobile_apps PRIMARY KEY (id_mobile_app);

ALTER TABLE gn_commons.t_mobile_apps
    ADD CONSTRAINT unique_t_mobile_apps_app_code UNIQUE (app_code);

--Création de la table de versionning
CREATE TABLE gn_commons.t_migrations
(
  id_migration serial,
  migration_number integer NOT NULL,
  soft_code character varying(5),
  migration_comment text,
  install_date timestamp without time zone
);
COMMENT ON COLUMN gn_commons.t_migrations.migration_number IS 'Numéro de la version de la base';
COMMENT ON COLUMN gn_commons.t_migrations.soft_code IS 'code unique et permanent de l''application ou du module. Utiliser si possible le même code que celui défini dans utilisateurs.t_applications ou dans gn_commons.t_modules';
COMMENT ON COLUMN gn_commons.t_migrations.install_date IS 'date à laquelle la version actuelle a été mise à jour';
ALTER TABLE ONLY gn_commons.t_migrations
    ADD CONSTRAINT pk_t_migrations PRIMARY KEY (id_migration);
ALTER TABLE ONLY gn_commons.t_migrations
    ADD CONSTRAINT unique_t_migrations_migration_number UNIQUE (migration_number);