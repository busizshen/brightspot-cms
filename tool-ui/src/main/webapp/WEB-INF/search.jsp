<%@ page import="

com.psddev.cms.db.Content,
com.psddev.cms.db.Template,
com.psddev.cms.db.ToolUi,
com.psddev.cms.tool.PageWriter,
com.psddev.cms.tool.Search,
com.psddev.cms.tool.ToolPageContext,

com.psddev.dari.db.ObjectField,
com.psddev.dari.db.ObjectType,
com.psddev.dari.db.Query,
com.psddev.dari.db.State,
com.psddev.dari.util.ObjectUtils,

java.util.ArrayList,
java.util.Collections,
java.util.HashSet,
java.util.Iterator,
java.util.List,
java.util.Map,
java.util.Set,
java.util.UUID
" %><%

ToolPageContext wp = new ToolPageContext(pageContext);
PageWriter writer = wp.getWriter();
Search search = null;
String name = wp.param(String.class, Search.NAME_PARAMETER);

if (!wp.param(boolean.class, "reset") && name != null) {
    Map<String, Object> settings = (Map<String, Object>) wp.getUserSetting("search." + name);

    if (settings != null) {
        search = new Search(wp);
        search.getState().setValues(settings);
    }
}

if (search == null) {
    UUID[] typeIds = (UUID[]) request.getAttribute("validTypeIds");

    if (ObjectUtils.isBlank(typeIds)) {
        Class<?> typeClass = (Class<?>) request.getAttribute("validTypeClass");

        if (typeClass != null) {
            typeIds = new UUID[] { ObjectType.getInstance(typeClass).getId() };
        }
    }

    if (typeIds != null) {
        search = new Search(wp, typeIds);

    } else {
        search = new Search(wp);
    }
}

search.setName(name);

Set<ObjectType> validTypes = search.findValidTypes();
ObjectType selectedType = search.getSelectedType();

if (validTypes.isEmpty()) {
    validTypes.addAll(ObjectType.getInstance(Content.class).findConcreteTypes());
}

String resultTarget = wp.createId();
String newJsp = (String) request.getAttribute("newJsp");
String newTarget = (String) request.getAttribute("newTarget");
boolean singleType = validTypes.size() == 1;

writer.start("div", "class", "searchForm-container" + (singleType ? " searchForm-container-singleType" : ""));
    writer.start("div", "class", "searchForm-controls");

        writer.start("div", "class", "searchForm-filters");
            writer.start("h2").html("Filters").end();

            writer.start("form",
                    "method", "get",
                    "action", wp.url(null));

                writer.tag("input", "type", "hidden", "name", "reset", "value", "true");
                writer.tag("input", "type", "hidden", "name", Search.NAME_PARAMETER, "value", search.getName());

                for (ObjectType type : search.getTypes()) {
                    writer.tag("input", "type", "hidden", "name", Search.TYPES_PARAMETER, "value", type.getId());
                }

                writer.tag("input", "type", "hidden", "name", Search.IS_ONLY_PATHED, "value", search.isOnlyPathed());
                writer.tag("input", "type", "hidden", "name", Search.ADDITIONAL_QUERY_PARAMETER, "value", search.getAdditionalPredicate());
                writer.tag("input", "type", "hidden", "name", Search.PARENT_PARAMETER, "value", search.getParentId());

                if (!validTypes.isEmpty()) {
                    wp.typeSelect(
                            validTypes,
                            selectedType,
                            "All Types",
                            "class", "autoSubmit",
                            "name", Search.SELECTED_TYPE_PARAMETER,
                            "data-searchable", true);
                }

            writer.end();

            writer.start("form",
                    "class", "autoSubmit",
                    "method", "get",
                    "action", wp.url(request.getAttribute("resultJsp")),
                    "target", resultTarget);

                writer.tag("input", "type", "hidden", "name", Search.NAME_PARAMETER, "value", search.getName());
                writer.tag("input", "type", "hidden", "name", Search.SORT_PARAMETER, "value", search.getSort());

                for (ObjectType type : search.getTypes()) {
                    writer.tag("input", "type", "hidden", "name", Search.TYPES_PARAMETER, "value", type.getId());
                }

                writer.tag("input", "type", "hidden", "name", Search.IS_ONLY_PATHED, "value", search.isOnlyPathed());
                writer.tag("input", "type", "hidden", "name", Search.ADDITIONAL_QUERY_PARAMETER, "value", search.getAdditionalPredicate());
                writer.tag("input", "type", "hidden", "name", Search.PARENT_PARAMETER, "value", search.getParentId());
                writer.tag("input", "type", "hidden", "name", Search.OFFSET_PARAMETER, "value", search.getOffset());
                writer.tag("input", "type", "hidden", "name", Search.LIMIT_PARAMETER, "value", search.getLimit());
                writer.tag("input", "type", "hidden", "name", Search.SELECTED_TYPE_PARAMETER, "value", selectedType != null ? selectedType.getId() : null);

                writer.start("span", "class", "searchInput");
                    writer.start("label", "for", wp.createId()).html("Search").end();
                    writer.tag("input",
                            "type", "text",
                            "class", "autoFocus",
                            "id", wp.getId(),
                            "name", Search.QUERY_STRING_PARAMETER,
                            "value", search.getQueryString());
                    writer.start("button").html("Go").end();
                writer.end();

                if (selectedType != null) {
                    for (ObjectField field : selectedType.getIndexedFields()) {
                        ToolUi fieldUi = field.as(ToolUi.class);

                        if (fieldUi.isHidden()) {
                            continue;
                        }

                        if (!ObjectField.RECORD_TYPE.equals(field.getInternalItemType())) {
                            continue;
                        }

                        if (field.isEmbedded()) {
                            continue;
                        }

                        Set<ObjectType> fieldTypes = new HashSet<ObjectType>(field.getTypes());

                        for (Iterator<ObjectType> i = fieldTypes.iterator(); i.hasNext(); ) {
                            if (i.next().isEmbedded()) {
                                i.remove();
                            }
                        }

                        if (fieldTypes.isEmpty()) {
                            continue;
                        }

                        String fieldName = field.getInternalName();
                        StringBuilder fieldTypeIds = new StringBuilder();

                        if (!ObjectUtils.isBlank(fieldTypes)) {
                            for (ObjectType fieldType : fieldTypes) {
                                fieldTypeIds.append(fieldType.getId()).append(",");
                            }

                            fieldTypeIds.setLength(fieldTypeIds.length() - 1);
                        }

                        State fieldState = State.getInstance(Query.from(Object.class).where("_id = ?", search.getFieldFilters().get(fieldName)).first());

                        writer.start("span");
                            writer.tag("input",
                                    "type", "text",
                                    "class", "objectId",
                                    "name", "f." + fieldName,
                                    "placeholder", "Filter: " + field.getDisplayName(),
                                    "data-additional-query", field.getPredicate(),
                                    "data-editable", false,
                                    "data-label", fieldState != null ? fieldState.getLabel() : null,
                                    "data-pathed", ToolUi.isOnlyPathed(field),
                                    "data-searcher-path", fieldUi.getInputSearcherPath(),
                                    "data-typeIds", fieldTypeIds,
                                    "value", search.getFieldFilters().get(fieldName));
                        writer.end();
                    }
                }

            writer.end();

            writer.start("a", "class", "action-reset", "href", wp.url("", "reset", true)).html("Reset").end();

        writer.end();

        if (!ObjectUtils.isBlank(newJsp)) {
            writer.start("div", "class", "searchForm-create");
                writer.start("h2").html("Create").end();

                writer.start("form",
                        "method", "get",
                        "action", wp.url(newJsp),
                        "target", ObjectUtils.isBlank(newTarget) ? null : newTarget);

                    if (validTypes.size() == 1) {
                        ObjectType type = validTypes.iterator().next();

                        writer.tag("input", "type", "hidden", "name", "typeId", "value", type.getId());
                        writer.tag("input", "type", "submit", "value", "New " + wp.getObjectLabel(type), "style", "width: auto;");

                    } else {
                        wp.typeSelect(
                                validTypes,
                                selectedType,
                                null,
                                "name", "typeId",
                                "data-searchable", true);
                        writer.tag("input", "type", "submit", "value", "New");
                    }

                writer.end();
            writer.end();
        }

    writer.end();

    writer.start("div", "class", "searchForm-result frame", "name", resultTarget);
    writer.end();

writer.end();
%>
