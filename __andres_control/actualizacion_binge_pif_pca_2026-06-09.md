# Actualización metodológica — consumo episódico excesivo, fracciones de impacto potencial y ajuste per cápita

**Fecha:** 9 de junio de 2026

## Resumen

Esta nota documenta tres actualizaciones del análisis de mortalidad y años de vida potencialmente perdidos atribuibles al alcohol en lesiones: (i) el cambio en la medición del consumo episódico excesivo (HED, *heavy episodic drinking*) y sus implicancias de comparabilidad; (ii) la corrección de la integral que sustenta las fracciones atribuibles y de impacto potencial, necesaria para evaluar tanto escenarios de reducción de *binge* como de reducción de consumo; y (iii) el ajuste del consumo a las cifras de alcohol per cápita de la Organización Mundial de la Salud (OMS). Ninguno de estos puntos invalida los conteos de mortalidad ni la estructura del análisis; se trata de decisiones de consistencia y reproducibilidad que afectan el nivel de las fracciones estimadas.

## 1. Medición del consumo episódico excesivo (HED)

El proyecto convive con dos definiciones de HED que no son directamente comparables entre sí.

La **definición original**, basada en el cuestionario AUDIT-C, identifica el consumo episódico excesivo como la ingesta de seis o más tragos en una sola ocasión, sin distinguir por sexo ni por una ventana temporal específica; corresponde a un patrón de frecuencia habitual (nunca, mensual, semanal o diario) y está disponible para las olas 2008 a 2022.

La **definición nueva** proviene de una pregunta que recién aparece en 2012 y que cuantifica el número de **episodios** de consumo episódico excesivo durante los últimos treinta días, aplicando un umbral específico por sexo: cinco o más tragos en hombres y cuatro o más en mujeres. Esta serie se extiende hasta 2024. Conviene tener presente que esta variable cuenta episodios, no días: una misma persona puede tener más de un episodio en un día, de modo que el conteo puede superar los treinta.

Esta distinción aborda, y a la vez hace explícito, el comentario de los revisores: la introducción define el HED como cinco o más tragos en hombres y cuatro o más en mujeres, mientras que el análisis previo empleaba un umbral común de cinco para ambos sexos, y el marco temporal no quedaba claro. El estudio de Shield y colaboradores (Lancet Public Health), del cual provienen las funciones de riesgo específicas para bebedores con y sin consumo episódico excesivo, define el HED como al menos un episodio en los últimos treinta días. La definición nueva se alinea con ese marco; la original no.

El cambio de instrumento no es menor. Al estimar la prevalencia de HED entre bebedores actuales, los valores casi se duplican según la definición empleada: alrededor de 0,27 a 0,31 con la definición original y alrededor de 0,49 a 0,62 con la definición nueva alineada a Shield. En consecuencia, no se trata de afinar una misma medida, sino de dos operacionalizaciones distintas, y la elección mueve de manera apreciable las fracciones atribuibles.

La diferencia entre ambas medidas se observa también a nivel individual. Existe un grupo de personas que declaran una cantidad usual elevada de consumo por ocasión y, sin embargo, registran cero episodios de consumo episódico excesivo en los últimos treinta días; todas ellas son bebedoras actuales y la mayoría reporta episodios de *binge* en el AUDIT-C. La explicación es que la cantidad usual y la frecuencia del AUDIT-C describen un patrón habitual, sin ventana temporal, mientras que la pregunta nueva cuenta episodios en un mes específico: las personas con consumo episódico poco frecuente (mensual o menos) simplemente pueden no haber tenido un episodio en ese mes en particular. Esto ilustra de manera concreta la observación de los revisores sobre el marco temporal de la definición.

Como esta variable cuenta episodios y no días, conviene además revisar el paso que estima los días de consumo sin *binge* restando los episodios a los días totales de consumo: cuando una persona tiene más de un episodio por día, esa resta queda mal definida y puede anular su consumo no episódico. Es un punto a afinar en la construcción del volumen, aunque no altera la clasificación entre bebedores con y sin consumo episódico (que solo depende de tener al menos un episodio).

Una limitación relevante es que el instrumento nuevo no existe antes de 2012, de modo que las olas 2008 y 2010 no pueden armonizarse a la definición de los últimos treinta días. Esta limitación debe declararse de forma explícita.

Conviene, por último, distinguir dos efectos que operan en direcciones opuestas. La corrección de la integral (sección 2) reduce las fracciones estimadas en lesiones; el cambio en la definición de HED, en cambio, eleva la prevalencia de consumo episódico excesivo y tendería a aumentarlas. El efecto neto debe evaluarse empíricamente; lo que se mantiene robusto es que, una vez corregida la integral, las fracciones de lesiones se ubican en torno a 0,3.

## 2. Fracciones de impacto potencial: reducción de *binge* y reducción de consumo

Los revisores solicitaron evaluar las fracciones de impacto potencial no solo para escenarios de reducción del consumo episódico excesivo, sino también para escenarios de reducción del consumo total. La formulación anterior de la integral, que sumaba por separado tres tramos de la distribución de consumo, no permite representar correctamente el escenario de reducción de consumo y conducía además a una sobreestimación de las fracciones en lesiones, situándolas cerca de 0,5.

La corrección consiste en un modelo de dos componentes sobre una única grilla de consumo, en el que el parámetro de intervención se incorpora de manera distinta según el escenario. En la **reducción del consumo episódico excesivo**, se modifica la proporción de bebedores con *binge*, de modo que esa masa migra desde el grupo con consumo episódico hacia el grupo sin él. En la **reducción del consumo total**, las proporciones de cada grupo se mantienen fijas y el riesgo se reevalúa a un nivel de consumo menor; en otras palabras, la masa permanece dentro de su mismo grupo y solo disminuye su nivel de exposición.

Con esta formulación, las fracciones de impacto en lesiones se ubican en el orden de 0,3, consistente con la literatura comparativa (Estudio de Carga Global de Enfermedad e InterMAHP), en lugar del 0,5 obtenido originalmente.

## 3. Ajuste del consumo a las cifras de alcohol per cápita de la OMS

El procedimiento que ajusta el consumo declarado en la encuesta utiliza las cifras de alcohol per cápita de la OMS (litros de alcohol puro por persona de 15 años o más). Estas cifras deberían coincidir con la serie del Banco Mundial sobre consumo total de alcohol per cápita, que corresponde a la estimación de la OMS e incluye el consumo registrado y el no registrado, ajustado por turismo.

Tres aspectos requieren revisión, dado que escalan la totalidad del consumo y, por lo tanto, todas las fracciones estimadas.

En primer lugar, los valores de alcohol per cápita empleados se ubican por debajo de la cifra total reportada por la OMS y el Banco Mundial. Para 2010 y 2016, la OMS estima alrededor de 9,3 litros totales por persona, mientras que el procedimiento utiliza valores cercanos a 7 u 8 litros, más próximos al consumo solo registrado que al total.

En segundo lugar, el procedimiento aplica un factor de 0,8 sobre el valor de alcohol per cápita antes de transformarlo a gramos. Este factor es metodológicamente correcto: corresponde al ajuste propuesto por Rehm y colaboradores, según el cual solo alrededor del 80% del alcohol vendido o registrado llega a consumirse, ya que entre un 10 y un 20% se pierde por derrame, evaporación u otros usos. Es decir, el factor convierte el alcohol disponible en alcohol efectivamente ingerido, y es un supuesto habitual en la literatura comparativa (Rehm, Kehoe, InterMAHP y el Estudio de Carga Global de Enfermedad). El único punto a confirmar es que la cifra de partida sea el alcohol per cápita **total** de la OMS (registrado más no registrado), que es sobre el cual se aplica este ajuste; si la cifra de partida ya fuese el consumo solo registrado, el objetivo quedaría subestimado.

En tercer lugar, la equivalencia en gramos del trago estándar cambió entre versiones del análisis. La tesis de Castillo-Carniglia ofrece la referencia: el cuestionario AUDIT define el trago estándar como 13 gramos de alcohol puro (equivalente a una lata de cerveza de 333 ml, una copa de vino de 140 ml o un destilado de 40 ml), mientras que la Segunda Encuesta Nacional de Salud estimó un contenido promedio observado de 16 gramos por trago en Chile —superior al valor teórico por el tamaño de los vasos y los tragos combinados—. La densidad del etanol empleada en la conversión (0,789 gramos por mililitro) también coincide con esa referencia. Conviene fijar y declarar un único valor de trago estándar (13 gramos teóricos del AUDIT, 16 gramos empíricos de la encuesta chilena, o el valor cercano a 15,6 gramos de Shield y colaboradores), y que el comentario del código y el valor utilizado coincidan.

El efecto esperable de asegurar que la cifra de partida sea el alcohol per cápita total de la OMS es un aumento del consumo objetivo, hoy probablemente subestimado. Esto es coherente con la posición de Chile como uno de los países de mayor consumo de la región, que debería ubicarse por encima, y no por debajo, del promedio regional.

## Limitaciones y pasos siguientes

Las olas 2008 y 2010 no disponen del instrumento armonizado de consumo episódico excesivo, por lo que su tratamiento debe explicitarse como una limitación. La definición de HED debe declararse de manera unívoca y, de preferencia, alinearse con la ventana de treinta días utilizada por las funciones de riesgo. El trago estándar debe fijarse y declararse de acuerdo con una referencia explícita (AUDIT, la encuesta nacional chilena o Shield y colaboradores). El ajuste per cápita, basado en el factor de Rehm sobre la fracción consumida, está bien fundado; resta verificar que la cifra de alcohol per cápita utilizada como punto de partida sea la total de la OMS, idealmente reemplazando los valores fijos por la serie oficial del Banco Mundial. Finalmente, conviene reportar explícitamente que las fracciones de lesiones se ubican en torno a 0,3 una vez corregida la integral, y describir tanto el escenario de reducción de consumo episódico excesivo como el de reducción del consumo total solicitados por los revisores.

---

## Conversacion con Jose Ruiz-Tagle y Alvaro Castillo-Carniglia sobre YPLL e injuries

**Fecha y hora:** 2026-06-12 12:17:07 -04:00

Se converso con Jose Ruiz-Tagle y Alvaro Castillo-Carniglia sobre el articulo de YPLL e injuries. El punto central fue que el PCA, entendido aqui como el volumen de alcohol per capita o ajuste de volumen, tiene una correccion de binge drinking que se aplica despues, mas cerca de la funcion de la OMS, como en `ALCOHOL USE ESTIMATION_2026_06_092.R`. Esta version incorpora las correcciones de los revisores de Addiction y lleva la correccion desde aproximadamente 5 en la version anterior a aproximadamente 0.9 en la version actual.

El costo metodologico de esta correccion es perder 2008 y 2010, porque desde 2012 se pregunta el consumo de tragos con temporalidad de 30 dias, similar a lo usado por Shield, con umbral de 5 tragos en hombres y 4 en mujeres. Esto se compensa parcialmente incorporando 2024.

Ademas, se corrige la integral que antes estaba formulada como 0 a 60 para NHED y 60 a 150 para HED. Con la correccion actual se puede mover la masa de HED hacia NHED manteniendo el mismo nivel de consumo. Por lo tanto, esta especificacion debiese ser el analisis principal. En terminos de escenarios, interesa comparar una reduccion de 10% en HED versus una reduccion de 10% en PCA.

A ACC le gustaria ver el porcentaje de YPLL por lesiones atribuibles al alcohol sobre el total de YPLL por ano, para dimensionar el impacto, dado que son muertes altamente evitables y tienden a concentrarse en personas jovenes.

En la Tabla 1, JRT muestra que el consumo promedio de las personas HED es 13.3 g/dia, equivalente aproximadamente a un trago diario, versus 2.5 g/dia en NHED. En mujeres el promedio sube algo. Recordar que cada episodio de binge se multiplica por gramos; con N episodios, se recomendo reportar el promedio entre personas HED. JRT respondio que el promedio es 2.88 episodios, con rango 1 a 83. En principio esto no deberia afectar mayormente porque los consumos terminan capeados en 150; ACC considero que valores altos pueden ser plausibles en personas que toman mucho, dado que la variable registra episodios.

Tambien se discutio que no tiene mucho sentido la recomendacion de un revisor de usar 12 g en vez de 15.7 g por trago si luego la correccion per capita hace que el consumo ajustado termine igual. Salvo que exista una correccion especifica por sexo o por binge, el binge drinking no sera relevante ni afectara el consumo total ajustado, segun JRT, a menos que se asumiera que las mujeres o las personas con binge drinking subreportan diferencialmente su consumo.