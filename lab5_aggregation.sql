

-- ÉTAPE 1 : Connexion (à exécuter en ligne de commande)
-- mysql -u root -p
-- USE bibliotheque;



-- 1. Compter le nombre total d'abonnés
SELECT COUNT(*) AS total_abonnes
FROM abonne;

-- 2. Calculer la moyenne de prêts par abonné
SELECT AVG(nb) AS moyenne_emprunts
FROM (
  SELECT COUNT(*) AS nb
  FROM emprunt
  GROUP BY id_abonne
) AS sous_requete;

-- 3. Statistiques sur les ouvrages (pas de prix_unitaire dans cette base)
SELECT 
  COUNT(*) AS nombre_ouvrages,
  SUM(disponibilite) AS disponibles,
  COUNT(DISTINCT id_auteur) AS auteurs_uniques,
  ROUND(SUM(disponibilite) * 100.0 / COUNT(*), 2) AS pourcentage_disponibles
FROM ouvrage;


-- ÉTAPE 3 : Utilisation de GROUP BY

-- 4. Nombre d'emprunts par abonné
SELECT id_abonne, COUNT(*) AS nombre_emprunts
FROM emprunt
GROUP BY id_abonne;

-- 5. Nombre d'ouvrages par auteur
SELECT id_auteur, COUNT(*) AS total_ouvrages
FROM ouvrage
GROUP BY id_auteur;

-- Version avec nom des auteurs
SELECT 
  a.nom AS nom_auteur,
  COUNT(o.id_ouvrage) AS nombre_ouvrages
FROM auteur a
JOIN ouvrage o ON a.id_auteur = o.id_auteur
GROUP BY a.id_auteur, a.nom
ORDER BY nombre_ouvrages DESC;


-- ÉTAPE 4 : Filtrer les groupes avec HAVING
-- 

-- 6. Abonnés avec au moins 3 emprunts
SELECT id_abonne, COUNT(*) AS nombre_emprunts
FROM emprunt
GROUP BY id_abonne
HAVING COUNT(*) >= 3;

-- 7. Auteurs avec plus d'1 ouvrage
SELECT id_auteur, COUNT(*) AS total_ouvrages
FROM ouvrage
GROUP BY id_auteur
HAVING COUNT(*) > 1;

-- Version avec noms
SELECT 
  a.nom AS nom_auteur,
  COUNT(o.id_ouvrage) AS nombre_ouvrages
FROM auteur a
JOIN ouvrage o ON a.id_auteur = o.id_auteur
GROUP BY a.id_auteur, a.nom
HAVING COUNT(o.id_ouvrage) > 1
ORDER BY nombre_ouvrages DESC;


-- ÉTAPE 5 : Jointures et agrégats combinés


-- 8. Pour chaque abonné, nom et nombre d'emprunts
SELECT 
  a.nom AS nom_abonne,
  COUNT(e.id_emprunt) AS nombre_emprunts
FROM abonne a
LEFT JOIN emprunt e ON e.id_abonne = a.id_abonne
GROUP BY a.id_abonne, a.nom
ORDER BY nombre_emprunts DESC;

-- 9. Pour chaque auteur, nom et nombre total d'emprunts de ses ouvrages
SELECT 
  au.nom AS nom_auteur,
  COUNT(e.id_emprunt) AS total_emprunts
FROM auteur au
JOIN ouvrage o ON o.id_auteur = au.id_auteur
LEFT JOIN emprunt e ON e.id_ouvrage = o.id_ouvrage
GROUP BY au.id_auteur, au.nom
ORDER BY total_emprunts DESC;


-- ÉTAPE 6 : Analyses plus complexes


-- 10. Pourcentage d'ouvrages empruntés parmi tous les ouvrages
SELECT 
  ROUND(
    COUNT(DISTINCT CASE WHEN e.id_emprunt IS NOT NULL THEN o.id_ouvrage END) * 100.0 
    / COUNT(DISTINCT o.id_ouvrage), 
  2) AS pourcentage_ouvrages_empruntes
FROM ouvrage o
LEFT JOIN emprunt e ON e.id_ouvrage = o.id_ouvrage;

-- 11. Top 3 des abonnés les plus actifs
SELECT 
  a.nom AS nom_abonne,
  COUNT(*) AS nombre_emprunts
FROM abonne a
JOIN emprunt e ON e.id_abonne = a.id_abonne
GROUP BY a.id_abonne, a.nom
ORDER BY nombre_emprunts DESC
LIMIT 3;

-
-- ÉTAPE 7 : Sous-requêtes et CTE


-- 12. Auteurs dont la moyenne d'emprunts par ouvrage dépasse 2
WITH stats_auteurs AS (
  SELECT 
    o.id_auteur, 
    COUNT(e.id_emprunt) AS total_emprunts, 
    COUNT(DISTINCT o.id_ouvrage) AS nombre_ouvrages
  FROM ouvrage o
  LEFT JOIN emprunt e ON e.id_ouvrage = o.id_ouvrage
  GROUP BY o.id_auteur
)
SELECT 
  au.nom AS nom_auteur,
  sa.total_emprunts,
  sa.nombre_ouvrages,
  ROUND(sa.total_emprunts * 1.0 / sa.nombre_ouvrages, 2) AS moyenne_emprunts_par_ouvrage
FROM stats_auteurs sa
JOIN auteur au ON au.id_auteur = sa.id_auteur
WHERE sa.total_emprunts / sa.nombre_ouvrages > 2
ORDER BY moyenne_emprunts_par_ouvrage DESC;


-- ÉTAPE 8 : Optimisation


-- Vérifier les index existants
SHOW INDEX FROM emprunt;

-- Ajouter des index pour optimiser (à exécuter une seule fois)
-- CREATE INDEX idx_emprunt_abonne ON emprunt(id_abonne);
-- CREATE INDEX idx_emprunt_ouvrage ON emprunt(id_ouvrage);
-- CREATE INDEX idx_emprunt_dates ON emprunt(date_debut, date_fin);

-- Analyser le coût d'une requête
EXPLAIN SELECT id_abonne, COUNT(*) FROM emprunt GROUP BY id_abonne;


-- ÉTAPE 9 : Exercices pratiques


-- Exercice 1 : Nombre moyen d'emprunts par jour de la semaine
SELECT 
  DAYOFWEEK(date_debut) AS jour_numero,
  CASE DAYOFWEEK(date_debut)
    WHEN 1 THEN 'Dimanche'
    WHEN 2 THEN 'Lundi'
    WHEN 3 THEN 'Mardi'
    WHEN 4 THEN 'Mercredi'
    WHEN 5 THEN 'Jeudi'
    WHEN 6 THEN 'Vendredi'
    WHEN 7 THEN 'Samedi'
  END AS jour_semaine,
  COUNT(*) AS nombre_emprunts,
  ROUND(COUNT(*) * 1.0 / (SELECT COUNT(DISTINCT DATE(date_debut)) FROM emprunt), 2) AS moyenne_par_jour
FROM emprunt
GROUP BY jour_numero, jour_semaine
ORDER BY jour_numero;

-- Exercice 2 : Total d'emprunts par mois pour l'année en cours
SELECT 
  YEAR(date_debut) AS annee,
  MONTH(date_debut) AS mois,
  MONTHNAME(date_debut) AS nom_mois,
  COUNT(*) AS total_emprunts
FROM emprunt
WHERE YEAR(date_debut) = YEAR(CURDATE())
GROUP BY annee, mois, nom_mois
ORDER BY annee, mois;

-- Exercice 3 : Ouvrages jamais empruntés
-- Liste détaillée
SELECT 
  o.id_ouvrage,
  o.titre,
  au.nom AS auteur,
  o.disponibilite
FROM ouvrage o
JOIN auteur au ON au.id_auteur = o.id_auteur
LEFT JOIN emprunt e ON e.id_ouvrage = o.id_ouvrage
WHERE e.id_emprunt IS NULL
ORDER BY o.titre;

-- Statistiques
SELECT 
  COUNT(*) AS ouvrages_jamais_empruntes,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ouvrage), 2) AS pourcentage_non_empruntes
FROM ouvrage o
LEFT JOIN emprunt e ON e.id_ouvrage = o.id_ouvrage
WHERE e.id_emprunt IS NULL;

--
-- ANALYSES COMPLÉMENTAIRES
-

-- Durée moyenne des emprunts (en jours)
SELECT 
  ROUND(AVG(DATEDIFF(date_fin, date_debut)), 2) AS duree_moyenne_jours
FROM emprunt
WHERE date_fin IS NOT NULL;

-- Évolution mensuelle des emprunts
SELECT 
  DATE_FORMAT(date_debut, '%Y-%m') AS mois_annee,
  COUNT(*) AS emprunts_mois,
  LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(date_debut, '%Y-%m')) AS emprunts_mois_precedent,
  ROUND(
    (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(date_debut, '%Y-%m'))) * 100.0 
    / NULLIF(LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(date_debut, '%Y-%m')), 0), 
  2) AS evolution_pourcentage
FROM emprunt
GROUP BY mois_annee
ORDER BY mois_annee;

-- Abonnés inactifs (aucun emprunt dans les 6 derniers mois)
SELECT 
  a.nom,
  a.id_abonne,
  MAX(e.date_debut) AS dernier_emprunt,
  DATEDIFF(CURDATE(), MAX(e.date_debut)) AS jours_inactifs
FROM abonne a
LEFT JOIN emprunt e ON e.id_abonne = a.id_abonne
GROUP BY a.id_abonne, a.nom
HAVING MAX(e.date_debut) IS NULL 
   OR DATEDIFF(CURDATE(), MAX(e.date_debut)) > 180
ORDER BY jours_inactifs DESC;