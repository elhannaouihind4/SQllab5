
-- Base : bibliotheque


-- Vérification des données disponibles pour 2025
SELECT 
    MIN(date_debut) AS premiere_date,
    MAX(date_debut) AS derniere_date,
    COUNT(*) AS total_emprunts_2025
FROM emprunt 
WHERE YEAR(date_debut) = 2025;

-- ÉTAPE 1 : CTE pour les données mensuelles de base


WITH emprunts_2025 AS (
    -- Extraction des données d'emprunt pour 2025 avec calcul du mois
    SELECT 
        id_emprunt,
        id_ouvrage,
        id_abonne,
        date_debut,
        date_fin,
        YEAR(date_debut) AS annee,
        MONTH(date_debut) AS mois,
        MONTHNAME(date_debut) AS nom_mois
    FROM emprunt
    WHERE YEAR(date_debut) = 2025
),

-- 
-- ÉTAPE 2 : Indicateurs de base par mois


stats_mensuelles AS (
    -- Calcul des statistiques mensuelles de base
    SELECT 
        annee,
        mois,
        nom_mois,
        COUNT(*) AS total_emprunts,
        COUNT(DISTINCT id_abonne) AS abonnes_actifs,
        ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT id_abonne), 0), 2) AS moyenne_par_abonne
    FROM emprunts_2025
    GROUP BY annee, mois, nom_mois
),


-- ÉTAPE 3 : Top 3 des ouvrages par mois


emprunts_par_ouvrage AS (
    -- Comptage des emprunts par ouvrage et par mois
    SELECT 
        annee,
        mois,
        id_ouvrage,
        COUNT(*) AS nombre_emprunts
    FROM emprunts_2025
    GROUP BY annee, mois, id_ouvrage
),

classement_ouvrages AS (
    -- Classement des ouvrages par mois
    SELECT 
        annee,
        mois,
        id_ouvrage,
        nombre_emprunts,
        ROW_NUMBER() OVER (
            PARTITION BY annee, mois 
            ORDER BY nombre_emprunts DESC, id_ouvrage
        ) AS rang
    FROM emprunts_par_ouvrage
),

top3_ouvrages_mois AS (
    -- Sélection des 3 premiers ouvrages par mois
    SELECT 
        co.annee,
        co.mois,
        GROUP_CONCAT(
            CONCAT(o.titre, ' (', co.nombre_emprunts, ')')
            ORDER BY co.rang
            SEPARATOR ', '
        ) AS top3_titres
    FROM classement_ouvrages co
    JOIN ouvrage o ON o.id_ouvrage = co.id_ouvrage
    WHERE co.rang <= 3
    GROUP BY co.annee, co.mois
),

-
-- ÉTAPE 4 : Pourcentage d'ouvrages empruntés par mois
-- 

ouvrages_empruntes_mois AS (
    -- Nombre d'ouvrages distincts empruntés par mois
    SELECT 
        annee,
        mois,
        COUNT(DISTINCT id_ouvrage) AS ouvrages_empruntes
    FROM emprunts_2025
    GROUP BY annee, mois
),

-- Nombre total d'ouvrages dans la bibliothèque
total_ouvrages AS (
    SELECT COUNT(*) AS nb_total_ouvrages FROM ouvrage
),

pct_ouvrages_mois AS (
    -- Calcul du pourcentage d'ouvrages empruntés par mois
    SELECT 
        oem.annee,
        oem.mois,
        oem.ouvrages_empruntes,
        t.nb_total_ouvrages,
        ROUND(
            oem.ouvrages_empruntes * 100.0 / t.nb_total_ouvrages, 
            2
        ) AS pourcentage_empruntes
    FROM ouvrages_empruntes_mois oem
    CROSS JOIN total_ouvrages t
),

-- 
-- ÉTAPE 5 : Génération de tous les mois de 2025 (pour avoir les mois sans activité)
-- 

mois_2025 AS (
    SELECT 2025 AS annee, 1 AS mois, 'January' AS nom_mois UNION ALL
    SELECT 2025, 2, 'February' UNION ALL
    SELECT 2025, 3, 'March' UNION ALL
    SELECT 2025, 4, 'April' UNION ALL
    SELECT 2025, 5, 'May' UNION ALL
    SELECT 2025, 6, 'June' UNION ALL
    SELECT 2025, 7, 'July' UNION ALL
    SELECT 2025, 8, 'August' UNION ALL
    SELECT 2025, 9, 'September' UNION ALL
    SELECT 2025, 10, 'October' UNION ALL
    SELECT 2025, 11, 'November' UNION ALL
    SELECT 2025, 12, 'December'
)

-- 
-- ÉTAPE 6 : Rapport final assemblé
-- 

SELECT 
    -- Mois
    m.annee,
    m.mois,
    m.nom_mois AS mois_nom,
    
    -- Indicateurs de base
    COALESCE(sm.total_emprunts, 0) AS total_emprunts,
    COALESCE(sm.abonnes_actifs, 0) AS abonnes_actifs,
    COALESCE(sm.moyenne_par_abonne, 0) AS moyenne_emprunts_par_abonne,
    
    -- Pourcentage d'ouvrages empruntés
    COALESCE(pom.pourcentage_empruntes, 0) AS pourcentage_ouvrages_empruntes,
    COALESCE(pom.ouvrages_empruntes, 0) AS ouvrages_empruntes,
    COALESCE(t.nb_total_ouvrages, 0) AS total_ouvrages_bibliotheque,
    
    -- Top 3 des ouvrages
    COALESCE(t3.top3_titres, 'Aucun emprunt ce mois') AS top3_ouvrages
    
FROM mois_2025 m
LEFT JOIN stats_mensuelles sm ON sm.annee = m.annee AND sm.mois = m.mois
LEFT JOIN pct_ouvrages_mois pom ON pom.annee = m.annee AND pom.mois = m.mois
LEFT JOIN top3_ouvrages_mois t3 ON t3.annee = m.annee AND t3.mois = m.mois
LEFT JOIN total_ouvrages t ON 1=1  -- Cross join pour avoir le total sur chaque ligne

ORDER BY m.annee, m.mois;

-- 
-- VERSION ALTERNATIVE : Rapport mensuel détaillé avec sous-requêtes
-- 

/*
-- Rapport avec plus de détails (si nécessaire)
SELECT 
    m.*,
    COALESCE(sm.total_emprunts, 0) AS total_emprunts,
    COALESCE(sm.abonnes_actifs, 0) AS abonnes_actifs,
    -- Calcul détaillé de la moyenne
    CASE 
        WHEN COALESCE(sm.abonnes_actifs, 0) > 0 
        THEN ROUND(COALESCE(sm.total_emprunts, 0) * 1.0 / sm.abonnes_actifs, 2)
        ELSE 0 
    END AS moyenne_calculee,
    
    -- Catégorisation de l'activité
    CASE 
        WHEN COALESCE(sm.total_emprunts, 0) = 0 THEN 'Aucune activité'
        WHEN COALESCE(sm.total_emprunts, 0) < 10 THEN 'Faible activité'
        WHEN COALESCE(sm.total_emprunts, 0) < 50 THEN 'Activité modérée'
        ELSE 'Forte activité'
    END AS niveau_activite,
    
    COALESCE(t3.top3_titres, 'N/A') AS ouvrages_populaires
    
FROM (
    -- Génération des mois avec LEFT JOIN pour inclure les mois sans activité
    SELECT 2025 AS annee, 1 AS mois, 'Janvier' AS nom_mois UNION ALL
    SELECT 2025, 2, 'Février' UNION ALL
    SELECT 2025, 3, 'Mars'
) m
LEFT JOIN (
    -- Statistiques mensuelles
    SELECT 
        YEAR(date_debut) AS annee,
        MONTH(date_debut) AS mois,
        COUNT(*) AS total_emprunts,
        COUNT(DISTINCT id_abonne) AS abonnes_actifs
    FROM emprunt
    WHERE YEAR(date_debut) = 2025
    GROUP BY YEAR(date_debut), MONTH(date_debut)
) sm ON sm.annee = m.annee AND sm.mois = m.mois
LEFT JOIN (
    -- Top 3 ouvrages par mois
    SELECT 
        YEAR(e.date_debut) AS annee,
        MONTH(e.date_debut) AS mois,
        GROUP_CONCAT(
            DISTINCT CONCAT(o.titre, ' (', cnt.nb, ')')
            ORDER BY cnt.nb DESC
            SEPARATOR ' | '
        ) AS top3_titres
    FROM emprunt e
    JOIN (
        SELECT 
            id_ouvrage,
            YEAR(date_debut) AS annee,
            MONTH(date_debut) AS mois,
            COUNT(*) AS nb,
            ROW_NUMBER() OVER (
                PARTITION BY YEAR(date_debut), MONTH(date_debut) 
                ORDER BY COUNT(*) DESC
            ) AS rang
        FROM emprunt
        WHERE YEAR(date_debut) = 2025
        GROUP BY id_ouvrage, YEAR(date_debut), MONTH(date_debut)
    ) cnt ON cnt.id_ouvrage = e.id_ouvrage 
        AND YEAR(e.date_debut) = cnt.annee 
        AND MONTH(e.date_debut) = cnt.mois
    JOIN ouvrage o ON o.id_ouvrage = e.id_ouvrage
    WHERE cnt.rang <= 3
    GROUP BY YEAR(e.date_debut), MONTH(e.date_debut)
) t3 ON t3.annee = m.annee AND t3.mois = m.mois

ORDER BY m.annee, m.mois;
*/

-- 
-- REQUÊTES SUPPLÉMENTAIRES POUR ANALYSE
-- 

-- Vérification des données pour les premiers mois de 2025
SELECT 
    MONTH(date_debut) AS mois,
    COUNT(*) AS emprunts,
    COUNT(DISTINCT id_abonne) AS abonnes,
    COUNT(DISTINCT id_ouvrage) AS ouvrages
FROM emprunt
WHERE YEAR(date_debut) = 2025
    AND MONTH(date_debut) IN (1, 2, 3)
GROUP BY MONTH(date_debut)
ORDER BY mois;

-- Détail des emprunts par jour pour janvier 2025
SELECT 
    DATE(date_debut) AS jour,
    COUNT(*) AS emprunts_jour,
    GROUP_CONCAT(DISTINCT a.nom ORDER BY a.nom SEPARATOR ', ') AS abonnes_actifs
FROM emprunt e
JOIN abonne a ON a.id_abonne = e.id_abonne
WHERE YEAR(date_debut) = 2025
    AND MONTH(date_debut) = 1
GROUP BY DATE(date_debut)
ORDER BY jour;

-- Analyse des ouvrages les plus populaires sur l'année
SELECT 
    o.titre,
    a.nom AS auteur,
    COUNT(e.id_emprunt) AS total_emprunts_2025,
    COUNT(DISTINCT MONTH(e.date_debut)) AS mois_avec_emprunt
FROM ouvrage o
JOIN auteur a ON a.id_auteur = o.id_auteur
LEFT JOIN emprunt e ON e.id_ouvrage = o.id_ouvrage 
    AND YEAR(e.date_debut) = 2025
GROUP BY o.id_ouvrage, o.titre, a.nom
ORDER BY total_emprunts_2025 DESC
LIMIT 10;
emprunts_2025 : Filtre les emprunts de l'année 2025 et extrait l'année/mois

stats_mensuelles : Calcule les indicateurs de base par mois

emprunts_par_ouvrage : Agrège les emprunts par ouvrage et par mois

classement_ouvrages : Classe les ouvrages par popularité mensuelle

top3_ouvrages_mois : Sélectionne et formate les 3 premiers ouvrages

ouvrages_empruntes_mois : Compte les ouvrages distincts empruntés par mois

total_ouvrages : Calcule le nombre total d'ouvrages dans la bibliothèque

pct_ouvrages_mois : Calcule le pourcentage d'ouvrages empruntés

mois_2025 : Génère tous les mois de l'année 2025